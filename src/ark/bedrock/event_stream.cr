require "io"

module Ark::Bedrock
  # Decodes AWS binary event stream protocol (application/vnd.amazon.eventstream).
  #
  # Frame layout:
  #   4 bytes  total byte length (big-endian)
  #   4 bytes  headers byte length (big-endian)
  #   4 bytes  prelude CRC32
  #   N bytes  headers
  #   M bytes  payload
  #   4 bytes  message CRC32
  module EventStream
    struct Message
      getter headers : Hash(String, String)
      getter payload : Bytes

      def initialize(@headers : Hash(String, String), @payload : Bytes)
      end

      def event_type : String?
        @headers[":event-type"]?
      end

      def message_type : String?
        @headers[":message-type"]?
      end

      def exception? : Bool
        message_type == "exception"
      end

      def content_type : String?
        @headers[":content-type"]?
      end
    end

    # 16 MB — generous upper bound; Bedrock frames are typically < 1 MB.
    MAX_FRAME_SIZE = 16 * 1024 * 1024

    def self.decode(io : IO, & : Message ->) : Nil
      loop do
        prelude = Bytes.new(12)
        bytes_read = io.read_fully?(prelude)
        break if bytes_read.nil?

        total_length = read_uint32(prelude, 0)
        headers_length = read_uint32(prelude, 4)

        if total_length > MAX_FRAME_SIZE
          Log.warn { "event stream frame too large: #{total_length} bytes, skipping" }
          break
        end

        remaining = total_length.to_i32 - 12 - 4
        break if remaining < 0

        body = Bytes.new(remaining)
        io.read_fully(body)

        # Skip message CRC
        crc = Bytes.new(4)
        io.read_fully(crc)

        headers = decode_headers(body[0, headers_length])
        payload_offset = headers_length.to_i32
        payload = body[payload_offset, remaining - payload_offset]

        yield Message.new(headers, payload)
      end
    end

    private def self.read_uint32(bytes : Bytes, offset : Int32) : UInt32
      (bytes[offset].to_u32 << 24) |
        (bytes[offset + 1].to_u32 << 16) |
        (bytes[offset + 2].to_u32 << 8) |
        bytes[offset + 3].to_u32
    end

    # Fixed byte sizes for header types. -1 = variable length, -2 = unknown.
    HEADER_TYPE_SIZES = {
      0 => 0, 1 => 0, 2 => 1, 3 => 2, 4 => 4,
      5 => 8, 6 => -1, 7 => -1, 8 => 8, 9 => 16,
    }

    STRING_TYPE = 7_u8

    # Decodes event stream headers.
    # See: https://docs.aws.amazon.com/transcribe/latest/dg/event-stream.html
    private def self.decode_headers(data : Bytes) : Hash(String, String)
      headers = Hash(String, String).new
      pos = 0

      while pos < data.size
        name, header_type, pos = read_header_name(data, pos) || break

        size = HEADER_TYPE_SIZES.fetch(header_type.to_i32, -2)
        break if size == -2

        if size >= 0
          pos += size
        else
          value_len, pos = read_variable_length(data, pos) || break
          if header_type == STRING_TYPE
            break if pos + value_len > data.size
            headers[name] = String.new(data[pos, value_len])
          end
          pos += value_len
        end
      end

      headers
    end

    private def self.read_header_name(data : Bytes, pos : Int32) : {String, UInt8, Int32}?
      return nil if pos + 1 > data.size
      name_len = data[pos].to_i32
      pos += 1
      return nil if pos + name_len + 1 > data.size
      name = String.new(data[pos, name_len])
      pos += name_len
      header_type = data[pos]
      pos += 1
      {name, header_type, pos}
    end

    private def self.read_variable_length(data : Bytes, pos : Int32) : {Int32, Int32}?
      return nil if pos + 2 > data.size
      value_len = (data[pos].to_u16 << 8 | data[pos + 1].to_u16).to_i32
      {value_len, pos + 2}
    end
  end
end

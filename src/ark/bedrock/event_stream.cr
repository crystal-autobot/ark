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

    def self.decode(io : IO, & : Message ->) : Nil
      loop do
        # Read prelude: total_length (4) + headers_length (4) + prelude_crc (4) = 12 bytes
        prelude = Bytes.new(12)
        bytes_read = io.read_fully?(prelude)
        break if bytes_read.nil?

        total_length = read_uint32(prelude, 0)
        headers_length = read_uint32(prelude, 4)
        # Skip prelude CRC (bytes 8..11)

        # Remaining bytes after prelude: total - 12 (prelude) - 4 (message CRC)
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

    # Decodes event stream headers.
    # Each header: 1-byte name length, name bytes, 1-byte type (7 = string),
    # 2-byte value length, value bytes.
    private def self.decode_headers(data : Bytes) : Hash(String, String)
      headers = Hash(String, String).new
      pos = 0

      while pos < data.size
        name_len = data[pos].to_i32
        pos += 1
        name = String.new(data[pos, name_len])
        pos += name_len

        header_type = data[pos]
        pos += 1

        case header_type
        when 7 # String type
          value_len = (data[pos].to_u16 << 8 | data[pos + 1].to_u16).to_i32
          pos += 2
          value = String.new(data[pos, value_len])
          pos += value_len
          headers[name] = value
        else
          # Skip unknown types — for now just break to avoid infinite loop
          break
        end
      end

      headers
    end
  end
end

require "../../spec_helper"

describe Ark::Bedrock::EventStream do
  describe ".decode" do
    it "decodes a single event stream message" do
      io = build_event_stream_message(
        headers: {":event-type" => "chunk", ":message-type" => "event"},
        payload: %({"bytes":"aGVsbG8="})
      )

      messages = [] of Ark::Bedrock::EventStream::Message
      Ark::Bedrock::EventStream.decode(io) { |msg| messages << msg }

      messages.size.should eq(1)
      messages[0].event_type.should eq("chunk")
      messages[0].message_type.should eq("event")
      String.new(messages[0].payload).should eq(%({"bytes":"aGVsbG8="}))
    end

    it "decodes multiple messages" do
      io = IO::Memory.new
      msg1 = build_event_stream_bytes(
        headers: {":event-type" => "chunk", ":message-type" => "event"},
        payload: "payload1"
      )
      msg2 = build_event_stream_bytes(
        headers: {":event-type" => "files", ":message-type" => "event"},
        payload: "payload2"
      )
      io.write(msg1)
      io.write(msg2)
      io.rewind

      messages = [] of Ark::Bedrock::EventStream::Message
      Ark::Bedrock::EventStream.decode(io) { |msg| messages << msg }

      messages.size.should eq(2)
      messages[0].event_type.should eq("chunk")
      messages[1].event_type.should eq("files")
    end

    it "detects exception messages" do
      io = build_event_stream_message(
        headers: {":message-type" => "exception", ":exception-type" => "throttling"},
        payload: "error"
      )

      messages = [] of Ark::Bedrock::EventStream::Message
      Ark::Bedrock::EventStream.decode(io) { |msg| messages << msg }

      messages.size.should eq(1)
      messages[0].exception?.should be_true
    end

    it "handles empty stream" do
      io = IO::Memory.new
      messages = [] of Ark::Bedrock::EventStream::Message
      Ark::Bedrock::EventStream.decode(io) { |msg| messages << msg }
      messages.should be_empty
    end

    it "skips non-string headers and still reads string headers" do
      # Build a message with an int header (type 4, 4 bytes) before a string header
      headers_io = IO::Memory.new

      # Int header: "num" with type 4 (int), 4 bytes value
      int_name = "num"
      headers_io.write_byte(int_name.bytesize.to_u8)
      headers_io.write(int_name.to_slice)
      headers_io.write_byte(4_u8) # int type
      headers_io.write_bytes(42_u32, IO::ByteFormat::BigEndian)

      # String header: ":event-type" with value "chunk"
      str_name = ":event-type"
      str_value = "chunk"
      headers_io.write_byte(str_name.bytesize.to_u8)
      headers_io.write(str_name.to_slice)
      headers_io.write_byte(7_u8)
      headers_io.write_bytes(str_value.bytesize.to_u16, IO::ByteFormat::BigEndian)
      headers_io.write(str_value.to_slice)

      headers_bytes = headers_io.to_slice
      payload = "data".to_slice
      total_length = 12 + headers_bytes.size + payload.size + 4

      io = IO::Memory.new
      io.write_bytes(total_length.to_u32, IO::ByteFormat::BigEndian)
      io.write_bytes(headers_bytes.size.to_u32, IO::ByteFormat::BigEndian)
      io.write_bytes(0_u32, IO::ByteFormat::BigEndian)
      io.write(headers_bytes)
      io.write(payload)
      io.write_bytes(0_u32, IO::ByteFormat::BigEndian)
      io.rewind

      messages = [] of Ark::Bedrock::EventStream::Message
      Ark::Bedrock::EventStream.decode(io) { |msg| messages << msg }

      messages.size.should eq(1)
      messages[0].event_type.should eq("chunk")
    end
  end
end

# Helper to build an event stream binary message
private def build_event_stream_bytes(
  headers : Hash(String, String),
  payload : String,
) : Bytes
  # Encode headers
  headers_io = IO::Memory.new
  headers.each do |name, value|
    headers_io.write_byte(name.bytesize.to_u8)
    headers_io.write(name.to_slice)
    headers_io.write_byte(7_u8) # String type
    headers_io.write_bytes(value.bytesize.to_u16, IO::ByteFormat::BigEndian)
    headers_io.write(value.to_slice)
  end
  headers_bytes = headers_io.to_slice

  payload_bytes = payload.to_slice

  # Total: 12 (prelude) + headers + payload + 4 (message CRC)
  total_length = 12 + headers_bytes.size + payload_bytes.size + 4

  io = IO::Memory.new
  io.write_bytes(total_length.to_u32, IO::ByteFormat::BigEndian)
  io.write_bytes(headers_bytes.size.to_u32, IO::ByteFormat::BigEndian)
  io.write_bytes(0_u32, IO::ByteFormat::BigEndian) # prelude CRC (placeholder)
  io.write(headers_bytes)
  io.write(payload_bytes)
  io.write_bytes(0_u32, IO::ByteFormat::BigEndian) # message CRC (placeholder)

  io.to_slice
end

private def build_event_stream_message(
  headers : Hash(String, String),
  payload : String,
) : IO::Memory
  bytes = build_event_stream_bytes(headers, payload)
  io = IO::Memory.new
  io.write(bytes)
  io.rewind
  io
end

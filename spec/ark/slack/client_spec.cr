require "../../spec_helper"
require "./support"

private BOT_TOKEN = "xoxb-test"

private def json_response(body : String) : HTTP::Client::Response
  HTTP::Client::Response.new(200, body)
end

describe Ark::Slack::Client do
  it "calls the Slack API through the transport with the bot token" do
    transport = MockHTTPTransport.new
    transport.responder = ->(_call : MockHTTPTransport::Call) { json_response(%({"ok":true,"user_id":"UBOT"})) }

    Ark::Slack::Client.new(BOT_TOKEN, transport).auth_test.should eq("UBOT")

    call = transport.calls.first
    call.method.should eq("POST")
    call.url.should eq("https://slack.com/api/auth.test")
    call.headers.try(&.["Authorization"]?).should eq("Bearer #{BOT_TOKEN}")
  end

  it "surfaces a transport timeout to the caller" do
    transport = MockHTTPTransport.new
    transport.responder = ->(_call : MockHTTPTransport::Call) : HTTP::Client::Response { raise IO::TimeoutError.new("read timed out") }

    expect_raises(IO::TimeoutError) do
      Ark::Slack::Client.new(BOT_TOKEN, transport).post_message("C1", "hello")
    end
  end

  it "uploads file content through the transport" do
    upload_url = "https://files.slack.com/upload/v1/abc"
    transport = MockHTTPTransport.new
    transport.responder = ->(call : MockHTTPTransport::Call) do
      if call.url.includes?("files.getUploadURLExternal")
        json_response(%({"ok":true,"upload_url":"#{upload_url}","file_id":"F1"}))
      else
        json_response(MockHTTPTransport::OK_BODY)
      end
    end

    data = "a,b\n1,2".to_slice
    Ark::Slack::Client.new(BOT_TOKEN, transport).upload_file("C1", "1.0", "data.csv", data)

    transport.calls.map(&.url).should eq([
      "https://slack.com/api/files.getUploadURLExternal?filename=data.csv&length=#{data.size}",
      upload_url,
      "https://slack.com/api/files.completeUploadExternal",
    ])
    transport.calls[1].body.should eq(data)
  end
end

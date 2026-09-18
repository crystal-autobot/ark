require "../../spec_helper"
require "./support"

describe Ark::Slack::SocketMode do
  it "opens connections through the transport" do
    transport = MockHTTPTransport.new
    socket_mode = Ark::Slack::SocketMode.new("xapp-test", transport)
    transport.responder = ->(_call : MockHTTPTransport::Call) : HTTP::Client::Response do
      socket_mode.stop
      raise IO::TimeoutError.new("read timed out")
    end

    socket_mode.run { |_payload| }

    call = transport.calls.first
    call.url.should eq("https://slack.com/api/apps.connections.open")
    call.headers.try(&.["Authorization"]?).should eq("Bearer xapp-test")
  end
end

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

  it "reconnects when the connection goes silent" do
    hold = Channel(Nil).new
    silent_peer = ->(_socket : HTTP::WebSocket) { hold.receive? }

    with_websocket_server(silent_peer) do |url|
      transport = MockHTTPTransport.new
      socket_mode = Ark::Slack::SocketMode.new(
        "xapp-test",
        transport,
        heartbeat_interval: 20.milliseconds,
        heartbeat_timeout: 100.milliseconds,
        reconnect_delay: 10.milliseconds,
      )
      transport.responder = ->(_call : MockHTTPTransport::Call) : HTTP::Client::Response do
        if transport.calls.size > 1
          socket_mode.stop
          raise IO::TimeoutError.new("stop after the reconnect attempt")
        end
        HTTP::Client::Response.new(200, %({"ok":true,"url":"#{url}"}))
      end

      done = Channel(Nil).new
      spawn do
        socket_mode.run { |_payload| }
        done.send(nil)
      end

      finished_within?(done, 3.seconds).should be_true
      transport.calls.size.should eq(2)
    end
  ensure
    hold.try(&.close)
  end
end

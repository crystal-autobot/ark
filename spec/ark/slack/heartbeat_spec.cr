require "../../spec_helper"
require "./support"

describe Ark::Slack::Heartbeat do
  it "closes the connection when the peer goes silent" do
    hold = Channel(Nil).new
    silent_peer = ->(_socket : HTTP::WebSocket) { hold.receive? }

    with_websocket_server(silent_peer) do |url|
      ws = HTTP::WebSocket.new(URI.parse(url))
      Ark::Slack::Heartbeat.new(ws, interval: 20.milliseconds, timeout: 100.milliseconds).start

      done = Channel(Nil).new
      spawn do
        ws.run
        done.send(nil)
      end

      finished_within?(done, 3.seconds).should be_true
      ws.closed?.should be_true
    end
  ensure
    hold.try(&.close)
  end

  it "keeps a responsive connection open" do
    responsive_peer = ->(_socket : HTTP::WebSocket) { }

    with_websocket_server(responsive_peer) do |url|
      ws = HTTP::WebSocket.new(URI.parse(url))
      heartbeat = Ark::Slack::Heartbeat.new(ws, interval: 20.milliseconds, timeout: 300.milliseconds)
      heartbeat.start
      spawn { ws.run }

      sleep 700.milliseconds

      ws.closed?.should be_false
      heartbeat.stop
      ws.close
    end
  end
end

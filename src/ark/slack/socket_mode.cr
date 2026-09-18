require "http/web_socket"
require "json"

module Ark::Slack
  class SocketMode
    API_BASE           = "https://slack.com/api"
    RECONNECT_DELAY    = 5.seconds
    HEARTBEAT_INTERVAL = 10.seconds
    HEARTBEAT_TIMEOUT  = 30.seconds

    @running = true
    @ws : HTTP::WebSocket?

    def initialize(
      @app_token : String,
      @transport : HTTPTransport = HTTPTransport.new,
      @heartbeat_interval : Time::Span = HEARTBEAT_INTERVAL,
      @heartbeat_timeout : Time::Span = HEARTBEAT_TIMEOUT,
      @reconnect_delay : Time::Span = RECONNECT_DELAY,
    )
    end

    def run(&handler : JSON::Any ->) : Nil
      while @running
        begin
          listen(handler)
        rescue ex
          Log.error(exception: ex) { "socket mode: connection error" } if @running
        end

        break unless @running
        Log.info { "socket mode: reconnecting in #{@reconnect_delay.total_seconds}s" }
        sleep @reconnect_delay
      end
    end

    def stop : Nil
      @running = false
      @ws.try(&.close)
    end

    private def listen(handler : JSON::Any ->) : Nil
      ws = HTTP::WebSocket.new(URI.parse(open_connection))
      @ws = ws
      heartbeat = Heartbeat.new(ws, @heartbeat_interval, @heartbeat_timeout)

      Log.info { "socket mode: connected" }

      ws.on_message do |raw|
        heartbeat.touch
        handle_message(ws, raw, handler)
      end

      ws.on_close do |code, reason|
        Log.info { "socket mode: disconnected code=#{code} reason=#{reason}" }
      end

      heartbeat.start
      ws.run
    ensure
      heartbeat.try(&.stop)
      @ws = nil
    end

    private def open_connection : String
      headers = HTTP::Headers{"Authorization" => "Bearer #{@app_token}"}
      resp = @transport.post("#{API_BASE}/apps.connections.open", headers)
      json = JSON.parse(resp.body)

      unless json["ok"]?.try(&.as_bool?)
        error = json["error"]?.try(&.as_s?) || "unknown"
        raise "apps.connections.open failed: #{error}"
      end

      json["url"].as_s
    end

    private def handle_message(ws : HTTP::WebSocket, raw : String, handler : JSON::Any ->) : Nil
      json = JSON.parse(raw)

      if envelope_id = json["envelope_id"]?.try(&.as_s?)
        ws.send({envelope_id: envelope_id}.to_json)
      end

      type = json["type"]?.try(&.as_s?)
      return unless type == "events_api"

      if payload = json["payload"]?
        handler.call(payload)
      end
    rescue ex
      Log.error(exception: ex) { "socket mode: failed to handle message" }
    end
  end
end

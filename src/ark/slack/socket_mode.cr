require "http/web_socket"
require "json"

module Ark::Slack
  class SocketMode
    API_BASE        = "https://slack.com/api"
    RECONNECT_DELAY = 5.seconds

    @running = true

    def initialize(@app_token : String)
    end

    def run(&handler : JSON::Any ->) : Nil
      while @running
        begin
          ws_url = open_connection
          ws = HTTP::WebSocket.new(URI.parse(ws_url))

          Log.info { "socket mode: connected" }

          ws.on_message do |raw|
            handle_message(ws, raw, handler)
          end

          ws.on_close do |code, reason|
            Log.info { "socket mode: disconnected code=#{code} reason=#{reason}" }
          end

          ws.run
        rescue ex
          Log.error(exception: ex) { "socket mode: connection error" }
        end

        break unless @running
        Log.info { "socket mode: reconnecting in #{RECONNECT_DELAY.total_seconds}s" }
        sleep RECONNECT_DELAY
      end
    end

    def stop : Nil
      @running = false
    end

    private def open_connection : String
      headers = HTTP::Headers{"Authorization" => "Bearer #{@app_token}"}
      resp = HTTP::Client.post("#{API_BASE}/apps.connections.open", headers: headers)
      json = JSON.parse(resp.body)

      unless json["ok"]?.try(&.as_bool?)
        error = json["error"]?.try(&.as_s?) || "unknown"
        raise "apps.connections.open failed: #{error}"
      end

      json["url"].as_s
    end

    private def handle_message(ws : HTTP::WebSocket, raw : String, handler : JSON::Any ->) : Nil
      json = JSON.parse(raw)

      # Acknowledge the envelope
      if envelope_id = json["envelope_id"]?.try(&.as_s?)
        ws.send({envelope_id: envelope_id}.to_json)
      end

      # Only process events_api payloads
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

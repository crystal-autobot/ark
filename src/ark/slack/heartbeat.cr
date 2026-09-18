require "http/web_socket"

module Ark::Slack
  class Heartbeat
    def initialize(@ws : HTTP::WebSocket, @interval : Time::Span, @timeout : Time::Span)
      @last_seen = Time.instant
      @running = false
      @ws.on_ping { touch }
      @ws.on_pong { touch }
    end

    def touch : Nil
      @last_seen = Time.instant
    end

    def start : Nil
      @running = true
      spawn { monitor }
    end

    def stop : Nil
      @running = false
    end

    private def monitor : Nil
      while active?
        sleep @interval
        break unless active?

        if stale?
          close_stale_connection
          break
        end

        @ws.ping
      end
    rescue ex : IO::Error
      Log.warn(exception: ex) { "socket mode: heartbeat failed" }
    end

    private def active? : Bool
      @running && !@ws.closed?
    end

    private def stale? : Bool
      @last_seen.elapsed > @timeout
    end

    private def close_stale_connection : Nil
      Log.warn { "socket mode: nothing received for #{@timeout.total_seconds}s, closing stale connection" }
      @ws.close
    end
  end
end

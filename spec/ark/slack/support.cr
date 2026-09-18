require "http/server"

class MockHTTPTransport < Ark::HTTPTransport
  record Call, method : String, url : String, headers : HTTP::Headers?, body : HTTP::Client::BodyType

  OK_BODY = %({"ok":true})

  getter calls = [] of Call
  property responder : Call -> HTTP::Client::Response = ->(_call : Call) { HTTP::Client::Response.new(200, OK_BODY) }

  def request(
    method : String,
    url : String,
    headers : HTTP::Headers? = nil,
    body : HTTP::Client::BodyType = nil,
  ) : HTTP::Client::Response
    call = Call.new(method, url, headers, body)
    @calls << call
    @responder.call(call)
  end
end

def with_websocket_server(on_connect : HTTP::WebSocket ->, &)
  handler = HTTP::WebSocketHandler.new { |socket, _context| on_connect.call(socket) }
  server = HTTP::Server.new(handler)
  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  yield "ws://#{address}"
ensure
  server.try(&.close)
end

def finished_within?(done : Channel(Nil), limit : Time::Span) : Bool
  select
  when done.receive
    true
  when timeout(limit)
    false
  end
end

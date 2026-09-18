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

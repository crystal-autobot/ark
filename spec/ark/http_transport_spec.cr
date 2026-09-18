require "../spec_helper"
require "http/server"

private def with_http_server(handler : HTTP::Handler::HandlerProc, &)
  server = HTTP::Server.new(handler)
  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  yield "http://#{address}"
ensure
  server.try(&.close)
end

private def with_silent_server(&)
  server = TCPServer.new("127.0.0.1", 0)
  yield "http://127.0.0.1:#{server.local_address.port}"
ensure
  server.try(&.close)
end

describe Ark::HTTPTransport do
  it "sends the method, target, headers and body" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      request = context.request
      body = request.body.try(&.gets_to_end)
      context.response.print("#{request.method} #{request.resource} #{request.headers["X-Test"]?} #{body}")
    end

    with_http_server(handler) do |url|
      response = Ark::HTTPTransport.new.post("#{url}/path?q=1", HTTP::Headers{"X-Test" => "yes"}, "payload")
      response.body.should eq("POST /path?q=1 yes payload")
    end
  end

  it "returns non-success responses without raising" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      context.response.status = HTTP::Status::TOO_MANY_REQUESTS
    end

    with_http_server(handler) do |url|
      Ark::HTTPTransport.new.get(url).status_code.should eq(429)
    end
  end

  it "raises a timeout when the server never responds" do
    transport = Ark::HTTPTransport.new(read_timeout: 50.milliseconds)

    with_silent_server do |url|
      expect_raises(IO::TimeoutError) { transport.get(url) }
    end
  end
end

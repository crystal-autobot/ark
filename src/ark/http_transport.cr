require "http/client"

module Ark
  class HTTPTransport
    DEFAULT_CONNECT_TIMEOUT = 10.seconds
    DEFAULT_READ_TIMEOUT    = 30.seconds
    DEFAULT_WRITE_TIMEOUT   = 30.seconds

    def initialize(
      @connect_timeout : Time::Span = DEFAULT_CONNECT_TIMEOUT,
      @read_timeout : Time::Span = DEFAULT_READ_TIMEOUT,
      @write_timeout : Time::Span = DEFAULT_WRITE_TIMEOUT,
    )
    end

    def get(url : String, headers : HTTP::Headers? = nil) : HTTP::Client::Response
      request("GET", url, headers)
    end

    def post(
      url : String,
      headers : HTTP::Headers? = nil,
      body : HTTP::Client::BodyType = nil,
    ) : HTTP::Client::Response
      request("POST", url, headers, body)
    end

    def request(
      method : String,
      url : String,
      headers : HTTP::Headers? = nil,
      body : HTTP::Client::BodyType = nil,
    ) : HTTP::Client::Response
      uri = URI.parse(url)
      client = HTTP::Client.new(uri)
      client.connect_timeout = @connect_timeout
      client.read_timeout = @read_timeout
      client.write_timeout = @write_timeout
      client.exec(method, uri.request_target, headers, body)
    ensure
      client.try(&.close)
    end
  end
end

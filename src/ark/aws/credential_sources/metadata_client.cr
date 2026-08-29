require "http/client"

module Ark::AWS::CredentialSources::MetadataClient
  CONNECT_TIMEOUT = 2.seconds
  READ_TIMEOUT    = 5.seconds

  def self.get(url : String, headers : HTTP::Headers = HTTP::Headers.new) : HTTP::Client::Response
    request("GET", url, headers)
  end

  def self.put(url : String, headers : HTTP::Headers = HTTP::Headers.new) : HTTP::Client::Response
    request("PUT", url, headers)
  end

  def self.post(url : String, headers : HTTP::Headers, body : String) : HTTP::Client::Response
    request("POST", url, headers, body)
  end

  private def self.request(method : String, url : String, headers : HTTP::Headers, body : String? = nil) : HTTP::Client::Response
    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    client.connect_timeout = CONNECT_TIMEOUT
    client.read_timeout = READ_TIMEOUT
    client.exec(method, uri.request_target, headers, body)
  ensure
    client.try(&.close)
  end
end

require "http/server"

CREDENTIALS_JSON = %({"AccessKeyId":"AKTEST","SecretAccessKey":"SKTEST","Token":"TKTEST","Expiration":"2030-01-01T00:00:00Z"})

def with_metadata_server(handler : HTTP::Handler::HandlerProc, &)
  server = HTTP::Server.new(handler)
  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  yield "http://#{address}"
ensure
  server.try(&.close)
end

def with_env(vars : Hash(String, String), &)
  vars.each { |key, value| ENV[key] = value }
  yield
ensure
  vars.each_key { |key| ENV.delete(key) }
end

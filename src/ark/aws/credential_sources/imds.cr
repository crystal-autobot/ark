module Ark::AWS::CredentialSources::Imds
  ENDPOINT         = "http://169.254.169.254"
  TOKEN_PATH       = "/latest/api/token"
  CREDENTIALS_PATH = "/latest/meta-data/iam/security-credentials/"
  TOKEN_TTL_HEADER = "X-aws-ec2-metadata-token-ttl-seconds"
  TOKEN_HEADER     = "X-aws-ec2-metadata-token"
  TOKEN_TTL        = "21600"

  def self.resolve(endpoint : String = ENDPOINT) : ResolvedCredentials
    headers = HTTP::Headers{TOKEN_HEADER => fetch_token(endpoint)}

    role = fetch(endpoint + CREDENTIALS_PATH, headers).lines.first?.try(&.strip).presence
    raise "no IAM role attached to the instance" unless role

    Credentials.from_json(fetch(endpoint + CREDENTIALS_PATH + role, headers), "instance metadata")
  end

  private def self.fetch_token(endpoint : String) : String
    resp = MetadataClient.put(endpoint + TOKEN_PATH, HTTP::Headers{TOKEN_TTL_HEADER => TOKEN_TTL})
    raise "IMDS token request returned #{resp.status_code}" unless resp.success?
    resp.body
  end

  private def self.fetch(url : String, headers : HTTP::Headers) : String
    resp = MetadataClient.get(url, headers)
    raise "IMDS returned #{resp.status_code} for #{url}" unless resp.success?
    resp.body
  end
end

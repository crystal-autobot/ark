module Ark::AWS::CredentialSources::Container
  RELATIVE_URI_ENV = "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"
  FULL_URI_ENV     = "AWS_CONTAINER_CREDENTIALS_FULL_URI"
  TOKEN_ENV        = "AWS_CONTAINER_AUTHORIZATION_TOKEN"
  TOKEN_FILE_ENV   = "AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE"
  ECS_ENDPOINT     = "http://169.254.170.2"

  def self.available? : Bool
    !!(ENV[RELATIVE_URI_ENV]? || ENV[FULL_URI_ENV]?)
  end

  def self.resolve : ResolvedCredentials
    headers = HTTP::Headers.new
    authorization_token.try { |token| headers["Authorization"] = token }

    resp = MetadataClient.get(endpoint, headers)
    raise "container credentials endpoint returned #{resp.status_code}" unless resp.success?

    Credentials.from_json(resp.body, "container credentials endpoint")
  end

  private def self.endpoint : String
    ENV[FULL_URI_ENV]? || "#{ECS_ENDPOINT}#{ENV[RELATIVE_URI_ENV]}"
  end

  private def self.authorization_token : String?
    ENV[TOKEN_FILE_ENV]?.try { |path| File.read(path).strip } || ENV[TOKEN_ENV]?
  end
end

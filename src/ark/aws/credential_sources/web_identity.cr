require "xml"

module Ark::AWS::CredentialSources::WebIdentity
  TOKEN_FILE_ENV       = "AWS_WEB_IDENTITY_TOKEN_FILE"
  ROLE_ARN_ENV         = "AWS_ROLE_ARN"
  SESSION_NAME_ENV     = "AWS_ROLE_SESSION_NAME"
  DEFAULT_SESSION_NAME = "ark"
  STS_API_VERSION      = "2011-06-15"

  def self.available? : Bool
    !!(ENV[TOKEN_FILE_ENV]? && ENV[ROLE_ARN_ENV]?)
  end

  def self.resolve(region : String, endpoint : String = "https://sts.#{region}.amazonaws.com/") : ResolvedCredentials
    headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
    resp = MetadataClient.post(endpoint, headers, request_body)

    unless resp.success?
      raise "STS AssumeRoleWithWebIdentity failed (#{resp.status_code}): #{element(resp.body, "Message")}"
    end

    parse_response(resp.body)
  end

  def self.parse_response(xml : String) : ResolvedCredentials
    creds = Credentials.new(
      access_key_id: required_element(xml, "AccessKeyId"),
      secret_access_key: required_element(xml, "SecretAccessKey"),
      session_token: required_element(xml, "SessionToken"),
    )
    expires_at = Time.parse_rfc3339(required_element(xml, "Expiration"))
    ResolvedCredentials.new(credentials: creds, expires_at: expires_at)
  end

  private def self.request_body : String
    URI::Params.build do |form|
      form.add "Action", "AssumeRoleWithWebIdentity"
      form.add "Version", STS_API_VERSION
      form.add "RoleArn", ENV[ROLE_ARN_ENV]
      form.add "RoleSessionName", ENV[SESSION_NAME_ENV]? || DEFAULT_SESSION_NAME
      form.add "WebIdentityToken", File.read(ENV[TOKEN_FILE_ENV]).strip
    end
  end

  private def self.required_element(xml : String, name : String) : String
    element(xml, name).presence || raise "STS response missing #{name}"
  end

  private def self.element(xml : String, name : String) : String
    XML.parse(xml).xpath_string("string(//*[local-name()='#{name}'])")
  end
end

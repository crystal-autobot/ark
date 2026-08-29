require "../../../spec_helper"
require "./support"

STS_RESPONSE = <<-XML
  <AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
    <AssumeRoleWithWebIdentityResult>
      <Credentials>
        <AccessKeyId>AKSTS</AccessKeyId>
        <SecretAccessKey>SKSTS</SecretAccessKey>
        <SessionToken>TKSTS</SessionToken>
        <Expiration>2030-01-01T00:00:00Z</Expiration>
      </Credentials>
    </AssumeRoleWithWebIdentityResult>
  </AssumeRoleWithWebIdentityResponse>
  XML

describe Ark::AWS::CredentialSources::WebIdentity do
  it "parses an STS response" do
    resolved = Ark::AWS::CredentialSources::WebIdentity.parse_response(STS_RESPONSE)
    resolved.credentials.access_key_id.should eq("AKSTS")
    resolved.credentials.secret_access_key.should eq("SKSTS")
    resolved.credentials.session_token.should eq("TKSTS")
    resolved.expires_at.should eq(Time.utc(2030, 1, 1))
  end

  it "raises on a response missing fields" do
    expect_raises(Exception, /missing AccessKeyId/) do
      Ark::AWS::CredentialSources::WebIdentity.parse_response("<Empty/>")
    end
  end

  it "posts the token and role to STS" do
    token_file = File.tempname("web-identity")
    File.write(token_file, "jwt-token")
    received = nil

    handler = HTTP::Handler::HandlerProc.new do |context|
      received = context.request.body.try(&.gets_to_end)
      context.response.print(STS_RESPONSE)
    end

    with_metadata_server(handler) do |url|
      env = {
        "AWS_WEB_IDENTITY_TOKEN_FILE" => token_file,
        "AWS_ROLE_ARN"                => "arn:aws:iam::123:role/ark",
      }
      with_env(env) do
        resolved = Ark::AWS::CredentialSources::WebIdentity.resolve("us-east-1", url)
        resolved.credentials.access_key_id.should eq("AKSTS")
      end
    end

    params = URI::Params.parse(received.not_nil!)
    params["Action"].should eq("AssumeRoleWithWebIdentity")
    params["RoleArn"].should eq("arn:aws:iam::123:role/ark")
    params["WebIdentityToken"].should eq("jwt-token")
  ensure
    File.delete(token_file) if token_file && File.exists?(token_file)
  end

  it "surfaces the STS error message" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      context.response.status = HTTP::Status::FORBIDDEN
      context.response.print(%(<ErrorResponse><Error><Message>Not authorized</Message></Error></ErrorResponse>))
    end

    with_metadata_server(handler) do |url|
      env = {"AWS_WEB_IDENTITY_TOKEN_FILE" => "/dev/null", "AWS_ROLE_ARN" => "arn"}
      with_env(env) do
        expect_raises(Exception, /Not authorized/) do
          Ark::AWS::CredentialSources::WebIdentity.resolve("us-east-1", url)
        end
      end
    end
  end
end

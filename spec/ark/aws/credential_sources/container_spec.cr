require "../../../spec_helper"
require "./support"

describe Ark::AWS::CredentialSources::Container do
  it "is available with either relative or full uri" do
    Ark::AWS::CredentialSources::Container.available?.should be_false
    with_env({"AWS_CONTAINER_CREDENTIALS_FULL_URI" => "http://x"}) do
      Ark::AWS::CredentialSources::Container.available?.should be_true
    end
  end

  it "resolves from a full uri with an authorization token file" do
    token_file = File.tempname("token")
    File.write(token_file, "secret-token\n")
    received_auth = nil

    handler = HTTP::Handler::HandlerProc.new do |context|
      received_auth = context.request.headers["Authorization"]?
      context.response.print(CREDENTIALS_JSON)
    end

    with_metadata_server(handler) do |url|
      env = {
        "AWS_CONTAINER_CREDENTIALS_FULL_URI"     => "#{url}/creds",
        "AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE" => token_file,
      }
      with_env(env) do
        resolved = Ark::AWS::CredentialSources::Container.resolve
        resolved.credentials.access_key_id.should eq("AKTEST")
        resolved.credentials.session_token.should eq("TKTEST")
        resolved.expires_at.should eq(Time.utc(2030, 1, 1))
      end
    end

    received_auth.should eq("secret-token")
  ensure
    File.delete(token_file) if token_file && File.exists?(token_file)
  end

  it "raises on non-success status" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      context.response.status = HTTP::Status::FORBIDDEN
    end

    with_metadata_server(handler) do |url|
      with_env({"AWS_CONTAINER_CREDENTIALS_FULL_URI" => url}) do
        expect_raises(Exception, /403/) { Ark::AWS::CredentialSources::Container.resolve }
      end
    end
  end
end

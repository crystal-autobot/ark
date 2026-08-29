require "../../../spec_helper"
require "./support"

describe Ark::AWS::CredentialSources::Imds do
  it "resolves instance profile credentials using IMDSv2" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      request = context.request
      case {request.method, request.path}
      when {"PUT", "/latest/api/token"}
        context.response.print("imds-token")
      when {"GET", "/latest/meta-data/iam/security-credentials/"}
        request.headers["X-aws-ec2-metadata-token"]?.should eq("imds-token")
        context.response.print("my-role\n")
      when {"GET", "/latest/meta-data/iam/security-credentials/my-role"}
        context.response.print(CREDENTIALS_JSON)
      else
        context.response.status = HTTP::Status::NOT_FOUND
      end
    end

    with_metadata_server(handler) do |url|
      resolved = Ark::AWS::CredentialSources::Imds.resolve(url)
      resolved.credentials.access_key_id.should eq("AKTEST")
      resolved.credentials.session_token.should eq("TKTEST")
    end
  end

  it "raises when no role is attached" do
    handler = HTTP::Handler::HandlerProc.new do |context|
      context.response.print("")
    end

    with_metadata_server(handler) do |url|
      expect_raises(Exception, /no IAM role/) { Ark::AWS::CredentialSources::Imds.resolve(url) }
    end
  end
end

require "../../../spec_helper"

describe Ark::AWS::CredentialSources::Cli do
  it "raises when aws CLI is not available or profile fails" do
    expect_raises(Exception, /AWS/) do
      Ark::AWS::CredentialSources::Cli.resolve("nonexistent-profile-#{Random.new.hex(8)}")
    end
  end
end

require "../../spec_helper"

describe Ark::AWS::StaticCredentialProvider do
  it "always returns the same credentials" do
    creds = Ark::AWS::Credentials.new("AKID", "secret", "token")
    provider = Ark::AWS::StaticCredentialProvider.new(creds)

    provider.credentials.should eq(creds)
    provider.credentials.should eq(creds)
  end
end

describe Ark::AWS::RefreshableCredentialProvider do
  it "returns cached credentials when not expired" do
    creds = Ark::AWS::Credentials.new("AKID", "secret")
    resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: creds,
      expires_at: Time.utc + 1.hour,
    )

    call_count = 0
    resolver = -> do
      call_count += 1
      resolved
    end

    provider = Ark::AWS::RefreshableCredentialProvider.new(resolved, resolver)
    provider.credentials.should eq(creds)
    provider.credentials.should eq(creds)
    call_count.should eq(0)
  end

  it "refreshes when within refresh window" do
    old_creds = Ark::AWS::Credentials.new("OLD", "old_secret")
    old_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: old_creds,
      expires_at: Time.utc + 5.minutes,
    )

    new_creds = Ark::AWS::Credentials.new("NEW", "new_secret")
    new_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: new_creds,
      expires_at: Time.utc + 1.hour,
    )

    resolver = -> { new_resolved }
    provider = Ark::AWS::RefreshableCredentialProvider.new(old_resolved, resolver)

    result = provider.credentials
    result.access_key_id.should eq("NEW")
  end

  it "refreshes when already expired" do
    old_creds = Ark::AWS::Credentials.new("OLD", "old_secret")
    old_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: old_creds,
      expires_at: Time.utc - 1.minute,
    )

    new_creds = Ark::AWS::Credentials.new("NEW", "new_secret")
    new_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: new_creds,
      expires_at: Time.utc + 1.hour,
    )

    resolver = -> { new_resolved }
    provider = Ark::AWS::RefreshableCredentialProvider.new(old_resolved, resolver)

    provider.credentials.access_key_id.should eq("NEW")
  end

  it "keeps cached credentials on refresh failure" do
    old_creds = Ark::AWS::Credentials.new("OLD", "old_secret")
    old_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: old_creds,
      expires_at: Time.utc + 5.minutes,
    )

    resolver = -> { raise "network error"; Ark::AWS::ResolvedCredentials.new(credentials: old_creds, expires_at: nil) }
    provider = Ark::AWS::RefreshableCredentialProvider.new(old_resolved, resolver)

    provider.credentials.access_key_id.should eq("OLD")
  end

  it "backs off after refresh failure" do
    old_creds = Ark::AWS::Credentials.new("OLD", "old_secret")
    old_resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: old_creds,
      expires_at: Time.utc + 5.minutes,
    )

    call_count = 0
    resolver = -> do
      call_count += 1
      raise "network error"
      Ark::AWS::ResolvedCredentials.new(credentials: old_creds, expires_at: nil)
    end

    provider = Ark::AWS::RefreshableCredentialProvider.new(old_resolved, resolver)
    provider.credentials
    provider.credentials
    provider.credentials
    call_count.should eq(1)
  end

  it "does not refresh when no expiry is set" do
    creds = Ark::AWS::Credentials.new("AKID", "secret")
    resolved = Ark::AWS::ResolvedCredentials.new(
      credentials: creds,
      expires_at: nil,
    )

    call_count = 0
    resolver = -> do
      call_count += 1
      resolved
    end

    provider = Ark::AWS::RefreshableCredentialProvider.new(resolved, resolver)
    provider.credentials.should eq(creds)
    call_count.should eq(0)
  end
end

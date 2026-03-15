require "../../spec_helper"
require "file_utils"

private def resolve_with_env(**extra) : Ark::AWS::ResolvedCredentials
  env_vars = {
    "SLACK_BOT_TOKEN"        => "xoxb-test",
    "SLACK_APP_TOKEN"        => "xapp-test",
    "BEDROCK_AGENT_ID"       => "agent-123",
    "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
  }
  env_vars.each { |key, val| ENV[key] = val }
  extra.each { |key, val| ENV[key.to_s] = val }

  begin
    config = Ark::Config.load
    Ark::AWS::Credentials.resolve(config)
  ensure
    env_vars.each_key { |key| ENV.delete(key) }
    extra.each { |key, _| ENV.delete(key.to_s) }
  end
end

describe Ark::AWS::Credentials do
  describe ".resolve_cli" do
    it "raises when aws CLI is not available or profile fails" do
      expect_raises(Exception, /AWS/) do
        Ark::AWS::Credentials.resolve_cli("nonexistent-profile-#{Random.new.hex(8)}")
      end
    end
  end

  describe ".region_from_profile" do
    it "reads region from config file" do
      dir = File.tempname("aws_config")
      Dir.mkdir_p(dir)
      File.write(File.join(dir, "config"), <<-INI
        [default]
        region = us-west-2

        [profile staging]
        region = eu-central-1
        INI
      )

      begin
        ENV["AWS_CONFIG_FILE"] = File.join(dir, "config")

        Ark::AWS::Credentials.region_from_profile("default").should eq("us-west-2")
        Ark::AWS::Credentials.region_from_profile("staging").should eq("eu-central-1")
      ensure
        ENV.delete("AWS_CONFIG_FILE")
        FileUtils.rm_rf(dir)
      end
    end

    it "returns nil when config file missing" do
      ENV["AWS_CONFIG_FILE"] = "/nonexistent/dir/config"

      begin
        Ark::AWS::Credentials.region_from_profile("any").should be_nil
      ensure
        ENV.delete("AWS_CONFIG_FILE")
      end
    end
  end

  describe ".resolve" do
    it "prefers explicit keys over profile" do
      resolved = resolve_with_env(
        AWS_ACCESS_KEY_ID: "AKEXPLICIT",
        AWS_SECRET_ACCESS_KEY: "secretexplicit",
        AWS_PROFILE: "should-be-ignored",
      )
      resolved.credentials.access_key_id.should eq("AKEXPLICIT")
    end

    it "returns nil expiry for explicit credentials" do
      resolved = resolve_with_env(
        AWS_ACCESS_KEY_ID: "AKRESOLVE",
        AWS_SECRET_ACCESS_KEY: "secretresolve",
      )
      resolved.credentials.access_key_id.should eq("AKRESOLVE")
      resolved.expires_at.should be_nil
    end
  end
end

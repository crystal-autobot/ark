require "../spec_helper"

describe Ark::Config do
  describe ".load_env_file" do
    it "loads key=value pairs from file" do
      path = File.tempname("ark_env")
      File.write(path, "FOO_TEST_VAR=bar\n")

      begin
        ENV.delete("FOO_TEST_VAR")
        Ark::Config.load_env_file(path)
        ENV["FOO_TEST_VAR"].should eq("bar")
      ensure
        ENV.delete("FOO_TEST_VAR")
        File.delete(path) if File.exists?(path)
      end
    end

    it "skips comments and blank lines" do
      path = File.tempname("ark_env")
      File.write(path, "# comment\n\nARK_TEST_KEY=value\n")

      begin
        ENV.delete("ARK_TEST_KEY")
        Ark::Config.load_env_file(path)
        ENV["ARK_TEST_KEY"].should eq("value")
      ensure
        ENV.delete("ARK_TEST_KEY")
        File.delete(path) if File.exists?(path)
      end
    end

    it "does not override existing env vars" do
      path = File.tempname("ark_env")
      File.write(path, "ARK_EXISTING=new\n")

      begin
        ENV["ARK_EXISTING"] = "old"
        Ark::Config.load_env_file(path)
        ENV["ARK_EXISTING"].should eq("old")
      ensure
        ENV.delete("ARK_EXISTING")
        File.delete(path) if File.exists?(path)
      end
    end

    it "does nothing for missing file" do
      Ark::Config.load_env_file("/nonexistent/path/.env")
    end
  end

  describe ".parse_log_level" do
    it "returns debug for 'debug'" do
      Ark::Config.parse_log_level("debug").should eq(Log::Severity::Debug)
    end

    it "returns warn for 'warn'" do
      Ark::Config.parse_log_level("warn").should eq(Log::Severity::Warn)
    end

    it "returns error for 'error'" do
      Ark::Config.parse_log_level("error").should eq(Log::Severity::Error)
    end

    it "returns info for 'info'" do
      Ark::Config.parse_log_level("info").should eq(Log::Severity::Info)
    end

    it "returns info for unknown levels" do
      Ark::Config.parse_log_level("unknown").should eq(Log::Severity::Info)
    end

    it "is case-insensitive" do
      Ark::Config.parse_log_level("DEBUG").should eq(Log::Severity::Debug)
    end
  end

  describe ".load" do
    it "raises on missing required vars" do
      %w[SLACK_BOT_TOKEN SLACK_APP_TOKEN BEDROCK_AGENT_ID BEDROCK_AGENT_ALIAS_ID
        AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_PROFILE FIREHOSE_STREAM_NAME].each do |key|
        ENV.delete(key)
      end

      expect_raises(ArgumentError, /missing required env vars/) do
        Ark::Config.load
      end
    end

    it "raises when no AWS credentials strategy is provided" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
      }
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_PROFILE].each { |key| ENV.delete(key) }
      env_vars.each { |key, val| ENV[key] = val }

      begin
        expect_raises(ArgumentError, /AWS credentials required/) do
          Ark::Config.load
        end
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end

    it "loads config with explicit AWS keys" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
        "AWS_ACCESS_KEY_ID"      => "AKTEST",
        "AWS_SECRET_ACCESS_KEY"  => "secret",
        "AWS_REGION"             => "eu-west-1",
        "LOG_LEVEL"              => "debug",
      }
      ENV.delete("AWS_PROFILE")
      ENV.delete("FIREHOSE_STREAM_NAME")
      env_vars.each { |key, val| ENV[key] = val }

      begin
        config = Ark::Config.load
        config.slack_bot_token.should eq("xoxb-test")
        config.bedrock_agent_id.should eq("agent-123")
        config.aws_access_key_id.should eq("AKTEST")
        config.aws_secret_access_key.should eq("secret")
        config.aws_region.should eq("eu-west-1")
        config.aws_profile.should be_nil
        config.firehose_stream_name.should be_nil
        config.log_level.should eq("debug")
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end

    it "loads config with AWS_PROFILE" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
        "AWS_PROFILE"            => "my-profile",
      }
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY FIREHOSE_STREAM_NAME].each { |key| ENV.delete(key) }
      env_vars.each { |key, val| ENV[key] = val }

      begin
        config = Ark::Config.load
        config.aws_profile.should eq("my-profile")
        config.aws_access_key_id.should be_nil
        config.aws_secret_access_key.should be_nil
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end

    it "firehose_stream_name is optional" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
        "AWS_ACCESS_KEY_ID"      => "AKTEST",
        "AWS_SECRET_ACCESS_KEY"  => "secret",
        "FIREHOSE_STREAM_NAME"   => "my-stream",
      }
      env_vars.each { |key, val| ENV[key] = val }

      begin
        config = Ark::Config.load
        config.firehose_stream_name.should eq("my-stream")
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end

    it "uses defaults for optional vars" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
        "AWS_ACCESS_KEY_ID"      => "AKTEST",
        "AWS_SECRET_ACCESS_KEY"  => "secret",
      }
      ENV.delete("AWS_REGION")
      ENV.delete("LOG_LEVEL")
      ENV.delete("FIREHOSE_STREAM_NAME")
      env_vars.each { |key, val| ENV[key] = val }

      begin
        config = Ark::Config.load
        config.aws_region.should eq("us-east-1")
        config.log_level.should eq("info")
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end
  end
end

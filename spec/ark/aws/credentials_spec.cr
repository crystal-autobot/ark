require "../../spec_helper"
require "file_utils"

describe Ark::AWS::Credentials do
  describe ".from_profile" do
    it "reads credentials from INI file" do
      dir = File.tempname("aws_creds")
      Dir.mkdir_p(dir)
      File.write(File.join(dir, "credentials"), <<-INI
        [default]
        aws_access_key_id = AKDEFAULT
        aws_secret_access_key = secretdefault

        [staging]
        aws_access_key_id = AKSTAGING
        aws_secret_access_key = secretstaging
        aws_session_token = tokenstaging
        INI
      )

      begin
        ENV["AWS_CONFIG_FILE"] = File.join(dir, "config")

        creds = Ark::AWS::Credentials.from_profile("staging")
        creds.access_key_id.should eq("AKSTAGING")
        creds.secret_access_key.should eq("secretstaging")
        creds.session_token.should eq("tokenstaging")
      ensure
        ENV.delete("AWS_CONFIG_FILE")
        FileUtils.rm_rf(dir)
      end
    end

    it "reads default profile" do
      dir = File.tempname("aws_creds")
      Dir.mkdir_p(dir)
      File.write(File.join(dir, "credentials"), <<-INI
        [default]
        aws_access_key_id = AKDEFAULT
        aws_secret_access_key = secretdefault
        INI
      )

      begin
        ENV["AWS_CONFIG_FILE"] = File.join(dir, "config")

        creds = Ark::AWS::Credentials.from_profile("default")
        creds.access_key_id.should eq("AKDEFAULT")
        creds.secret_access_key.should eq("secretdefault")
        creds.session_token.should be_nil
      ensure
        ENV.delete("AWS_CONFIG_FILE")
        FileUtils.rm_rf(dir)
      end
    end

    it "raises when profile is missing keys" do
      dir = File.tempname("aws_creds")
      Dir.mkdir_p(dir)
      File.write(File.join(dir, "credentials"), <<-INI
        [incomplete]
        aws_access_key_id = AKINC
        INI
      )

      begin
        ENV["AWS_CONFIG_FILE"] = File.join(dir, "config")

        expect_raises(Exception, /missing aws_access_key_id or aws_secret_access_key/) do
          Ark::AWS::Credentials.from_profile("incomplete")
        end
      ensure
        ENV.delete("AWS_CONFIG_FILE")
        FileUtils.rm_rf(dir)
      end
    end

    it "raises when credentials file is missing" do
      ENV["AWS_CONFIG_FILE"] = "/nonexistent/dir/config"

      begin
        expect_raises(Exception, /credentials file not found/) do
          Ark::AWS::Credentials.from_profile("any")
        end
      ensure
        ENV.delete("AWS_CONFIG_FILE")
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

  describe ".from_config" do
    it "prefers explicit keys over profile" do
      env_vars = {
        "SLACK_BOT_TOKEN"        => "xoxb-test",
        "SLACK_APP_TOKEN"        => "xapp-test",
        "BEDROCK_AGENT_ID"       => "agent-123",
        "BEDROCK_AGENT_ALIAS_ID" => "alias-456",
        "AWS_ACCESS_KEY_ID"      => "AKEXPLICIT",
        "AWS_SECRET_ACCESS_KEY"  => "secretexplicit",
        "AWS_PROFILE"            => "should-be-ignored",
      }
      env_vars.each { |key, val| ENV[key] = val }

      begin
        config = Ark::Config.load
        creds = Ark::AWS::Credentials.from_config(config)
        creds.access_key_id.should eq("AKEXPLICIT")
      ensure
        env_vars.each_key { |key| ENV.delete(key) }
      end
    end
  end
end

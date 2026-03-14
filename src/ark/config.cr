module Ark
  class Config
    DEFAULT_AWS_REGION = "us-east-1"
    DEFAULT_LOG_LEVEL  = "info"
    ENV_FILE_PATH      = ".env"

    getter slack_bot_token : String
    getter slack_app_token : String
    getter bedrock_agent_id : String
    getter bedrock_agent_alias_id : String
    getter firehose_stream_name : String?
    getter aws_region : String
    getter aws_profile : String?
    getter aws_access_key_id : String?
    getter aws_secret_access_key : String?
    getter aws_session_token : String?
    getter log_level : String

    def initialize(
      @slack_bot_token : String,
      @slack_app_token : String,
      @bedrock_agent_id : String,
      @bedrock_agent_alias_id : String,
      @firehose_stream_name : String?,
      @aws_region : String,
      @aws_profile : String?,
      @aws_access_key_id : String?,
      @aws_secret_access_key : String?,
      @aws_session_token : String?,
      @log_level : String,
    )
    end

    REQUIRED_VARS = %w[
      SLACK_BOT_TOKEN SLACK_APP_TOKEN BEDROCK_AGENT_ID BEDROCK_AGENT_ALIAS_ID
    ]

    def self.load : Config
      load_env_file(ENV_FILE_PATH)

      values = {} of String => String
      missing = [] of String

      REQUIRED_VARS.each do |key|
        value = env(key)
        if value
          values[key] = value
        else
          missing << key
        end
      end

      unless missing.empty?
        raise ArgumentError.new("missing required env vars: #{missing.join(", ")}")
      end

      aws_profile = env("AWS_PROFILE")
      aws_access_key_id = env("AWS_ACCESS_KEY_ID")
      aws_secret_access_key = env("AWS_SECRET_ACCESS_KEY")

      if aws_profile.nil? && (aws_access_key_id.nil? || aws_secret_access_key.nil?)
        raise ArgumentError.new(
          "AWS credentials required: set AWS_PROFILE or both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        )
      end

      new(
        slack_bot_token: values["SLACK_BOT_TOKEN"],
        slack_app_token: values["SLACK_APP_TOKEN"],
        bedrock_agent_id: values["BEDROCK_AGENT_ID"],
        bedrock_agent_alias_id: values["BEDROCK_AGENT_ALIAS_ID"],
        firehose_stream_name: env("FIREHOSE_STREAM_NAME"),
        aws_region: env("AWS_REGION", DEFAULT_AWS_REGION).as(String),
        aws_profile: aws_profile,
        aws_access_key_id: aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key,
        aws_session_token: env("AWS_SESSION_TOKEN"),
        log_level: env("LOG_LEVEL", DEFAULT_LOG_LEVEL).as(String),
      )
    end

    def self.parse_log_level(level : String) : Log::Severity
      case level.downcase
      when "debug" then Log::Severity::Debug
      when "warn"  then Log::Severity::Warn
      when "error" then Log::Severity::Error
      else              Log::Severity::Info
      end
    end

    def self.load_env_file(path : String) : Nil
      return unless File.exists?(path)

      File.each_line(path) do |line|
        line = line.strip
        next if line.empty? || line.starts_with?('#')

        key, _, value = line.partition('=')
        key = key.strip
        value = value.strip
        ENV[key] ||= value unless key.empty?
      end
    end

    private def self.env(key : String, default : String? = nil) : String?
      value = ENV[key]?
      value.nil? || value.empty? ? default : value
    end
  end
end

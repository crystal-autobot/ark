module Ark
  class Config
    DEFAULT_AWS_REGION          = "us-east-1"
    DEFAULT_LOG_LEVEL           = "info"
    DEFAULT_SESSION_TTL_MINUTES = 55
    MIN_SESSION_TTL_MINUTES     =  1
    MAX_SESSION_TTL_MINUTES     = 60
    ENV_FILE_PATH               = ".env"

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
    getter session_ttl_minutes : Int32
    getter? streaming_enabled : Bool

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
      @session_ttl_minutes : Int32 = DEFAULT_SESSION_TTL_MINUTES,
      @streaming_enabled : Bool = true,
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

      new(
        slack_bot_token: values["SLACK_BOT_TOKEN"],
        slack_app_token: values["SLACK_APP_TOKEN"],
        bedrock_agent_id: values["BEDROCK_AGENT_ID"],
        bedrock_agent_alias_id: values["BEDROCK_AGENT_ALIAS_ID"],
        firehose_stream_name: env("FIREHOSE_STREAM_NAME"),
        aws_region: env("AWS_REGION", DEFAULT_AWS_REGION).as(String),
        aws_profile: env("AWS_PROFILE"),
        aws_access_key_id: env("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key: env("AWS_SECRET_ACCESS_KEY"),
        aws_session_token: env("AWS_SESSION_TOKEN"),
        log_level: env("LOG_LEVEL", DEFAULT_LOG_LEVEL).as(String),
        session_ttl_minutes: env_int("SESSION_TTL_MINUTES", DEFAULT_SESSION_TTL_MINUTES)
          .clamp(MIN_SESSION_TTL_MINUTES, MAX_SESSION_TTL_MINUTES),
        streaming_enabled: env_bool("STREAMING_ENABLED", true),
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

    private def self.env_int(key : String, default : Int32) : Int32
      env(key).try(&.to_i?) || default
    end

    private def self.env_bool(key : String, default : Bool) : Bool
      value = env(key)
      return default unless value
      value.downcase == "true" || value == "1"
    end
  end
end

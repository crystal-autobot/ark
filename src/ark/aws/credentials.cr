require "json"
require "http/client"

module Ark::AWS
  struct Credentials
    getter access_key_id : String
    getter secret_access_key : String
    getter session_token : String?

    def initialize(@access_key_id : String, @secret_access_key : String, @session_token : String? = nil)
    end

    # Resolves credentials in order:
    # 1. Explicit env vars (AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY)
    # 2. ECS container credentials (task role via metadata endpoint)
    # 3. AWS CLI export (SSO, assume-role, credential_process, instance profile)
    def self.from_config(config : Config) : Credentials
      if (key_id = config.aws_access_key_id) && (secret = config.aws_secret_access_key)
        Log.info { "using explicit AWS credentials" }
        return new(access_key_id: key_id, secret_access_key: secret, session_token: config.aws_session_token)
      end

      if ENV["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]?
        Log.info { "using ECS container credentials" }
        return from_ecs_metadata
      end

      label = config.aws_profile.try { |profile| " (profile: #{profile})" }
      Log.info { "using AWS CLI credentials#{label}" }
      from_cli(config.aws_profile)
    end

    # Reads credentials from the ECS container metadata endpoint.
    # ECS sets AWS_CONTAINER_CREDENTIALS_RELATIVE_URI automatically for task roles.
    def self.from_ecs_metadata : Credentials
      relative_uri = ENV["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]
      resp = HTTP::Client.get("http://169.254.170.2#{relative_uri}")

      unless resp.success?
        raise "ECS metadata endpoint returned #{resp.status_code}"
      end

      parse_credential_json(resp.body, "ECS metadata")
    end

    # Uses the AWS CLI to export credentials.
    # Supports SSO, assume-role, credential_process, instance profiles, etc.
    def self.from_cli(profile : String? = nil) : Credentials
      args = ["configure", "export-credentials"]
      args += ["--profile", profile] if profile

      output = IO::Memory.new
      error = IO::Memory.new

      begin
        status = Process.run("aws", args, output: output, error: error)
      rescue File::NotFoundError
        raise "AWS CLI not found. Install it or provide AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY"
      end

      unless status.success?
        label = profile ? "profile [#{profile}]" : "default chain"
        raise "failed to export AWS credentials (#{label}): #{error.to_s.strip}"
      end

      parse_credential_json(output.to_s, "AWS CLI")
    end

    # Reads region from ~/.aws/config for the given profile.
    def self.region_from_profile(profile : String) : String?
      config_path = File.join(aws_config_dir, "config")
      return nil unless File.exists?(config_path)

      section_name = profile == "default" ? "default" : "profile #{profile}"
      section = parse_ini_section(config_path, section_name)
      section["region"]?
    end

    private def self.parse_credential_json(body : String, source : String) : Credentials
      json = JSON.parse(body)
      access_key = json["AccessKeyId"]?.try(&.as_s?)
      secret_key = json["SecretAccessKey"]?.try(&.as_s?)

      unless access_key && secret_key
        raise "#{source} returned incomplete credentials"
      end

      new(
        access_key_id: access_key,
        secret_access_key: secret_key,
        session_token: json["SessionToken"]?.try(&.as_s?) || json["Token"]?.try(&.as_s?),
      )
    end

    private def self.aws_config_dir : String
      ENV["AWS_CONFIG_FILE"]?.try { |path| File.dirname(path) } || File.join(Path.home, ".aws")
    end

    # Minimal INI parser — reads key=value pairs for a [section].
    private def self.parse_ini_section(path : String, section : String) : Hash(String, String)
      result = {} of String => String
      in_section = false

      File.each_line(path) do |line|
        line = line.strip
        next if line.empty? || line.starts_with?('#') || line.starts_with?(';')

        if line.starts_with?('[') && line.ends_with?(']')
          in_section = (line[1..-2].strip == section)
          next
        end

        next unless in_section

        key, _, value = line.partition('=')
        key = key.strip
        value = value.strip
        result[key] = value unless key.empty?
      end

      result
    end
  end
end

require "json"

module Ark::AWS
  struct Credentials
    getter access_key_id : String
    getter secret_access_key : String
    getter session_token : String?

    def initialize(@access_key_id : String, @secret_access_key : String, @session_token : String? = nil)
    end

    # Resolves credentials: explicit keys > AWS CLI export (supports SSO, assume-role, etc.)
    def self.from_config(config : Config) : Credentials
      if (key_id = config.aws_access_key_id) && (secret = config.aws_secret_access_key)
        return new(
          access_key_id: key_id,
          secret_access_key: secret,
          session_token: config.aws_session_token,
        )
      end

      if profile = config.aws_profile
        return from_cli(profile)
      end

      raise "no AWS credentials: set AWS_PROFILE or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY"
    end

    # Uses the AWS CLI to export credentials for any profile type (SSO, assume-role, static, etc.)
    def self.from_cli(profile : String) : Credentials
      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run("aws", ["configure", "export-credentials", "--profile", profile],
        output: output, error: error)

      unless status.success?
        msg = error.to_s.strip
        raise "failed to export AWS credentials for profile [#{profile}]: #{msg}"
      end

      json = JSON.parse(output.to_s)
      access_key = json["AccessKeyId"]?.try(&.as_s?)
      secret_key = json["SecretAccessKey"]?.try(&.as_s?)

      unless access_key && secret_key
        raise "AWS CLI returned incomplete credentials for profile [#{profile}]"
      end

      new(
        access_key_id: access_key,
        secret_access_key: secret_key,
        session_token: json["SessionToken"]?.try(&.as_s?),
      )
    end

    # Reads region from ~/.aws/config for the given profile.
    def self.region_from_profile(profile : String) : String?
      config_path = File.join(aws_config_dir, "config")
      return nil unless File.exists?(config_path)

      section_name = profile == "default" ? "default" : "profile #{profile}"
      section = parse_ini_section(config_path, section_name)
      section["region"]?
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

module Ark::AWS
  struct Credentials
    getter access_key_id : String
    getter secret_access_key : String
    getter session_token : String?

    def initialize(@access_key_id : String, @secret_access_key : String, @session_token : String? = nil)
    end

    # Resolves credentials from config: explicit keys take priority, then profile.
    def self.from_config(config : Config) : Credentials
      if (key_id = config.aws_access_key_id) && (secret = config.aws_secret_access_key)
        return new(
          access_key_id: key_id,
          secret_access_key: secret,
          session_token: config.aws_session_token,
        )
      end

      if profile = config.aws_profile
        return from_profile(profile)
      end

      raise "no AWS credentials: set AWS_PROFILE or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY"
    end

    # Reads credentials from ~/.aws/credentials for the given profile.
    def self.from_profile(profile : String) : Credentials
      credentials_path = File.join(aws_config_dir, "credentials")
      unless File.exists?(credentials_path)
        raise "AWS credentials file not found: #{credentials_path}"
      end

      section = parse_ini_section(credentials_path, profile)
      access_key = section["aws_access_key_id"]?
      secret_key = section["aws_secret_access_key"]?

      unless access_key && secret_key
        raise "profile [#{profile}] missing aws_access_key_id or aws_secret_access_key in #{credentials_path}"
      end

      new(
        access_key_id: access_key,
        secret_access_key: secret_key,
        session_token: section["aws_session_token"]?,
      )
    end

    # Reads region from ~/.aws/config for the given profile.
    def self.region_from_profile(profile : String) : String?
      config_path = File.join(aws_config_dir, "config")
      return nil unless File.exists?(config_path)

      # In ~/.aws/config, non-default profiles use "profile <name>" as section header.
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

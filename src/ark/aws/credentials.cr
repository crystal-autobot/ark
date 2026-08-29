require "json"

module Ark::AWS
  record ResolvedCredentials, credentials : Credentials, expires_at : Time?

  struct Credentials
    getter access_key_id : String
    getter secret_access_key : String
    getter session_token : String?

    def initialize(@access_key_id : String, @secret_access_key : String, @session_token : String? = nil)
    end

    def self.resolve(config : Config) : ResolvedCredentials
      if (key_id = config.aws_access_key_id) && (secret = config.aws_secret_access_key)
        Log.info { "using explicit AWS credentials" }
        creds = new(access_key_id: key_id, secret_access_key: secret, session_token: config.aws_session_token)
        return ResolvedCredentials.new(credentials: creds, expires_at: nil)
      end

      if CredentialSources::Container.available?
        Log.info { "using container credentials" }
        return CredentialSources::Container.resolve
      end

      if CredentialSources::WebIdentity.available?
        Log.info { "using web identity credentials" }
        return CredentialSources::WebIdentity.resolve(config.aws_region)
      end

      if CredentialSources::Cli.available?
        label = config.aws_profile.try { |profile| " (profile: #{profile})" }
        Log.info { "using AWS CLI credentials#{label}" }
        return CredentialSources::Cli.resolve(config.aws_profile)
      end

      Log.info { "using EC2 instance profile credentials" }
      resolve_instance_profile
    end

    private def self.resolve_instance_profile : ResolvedCredentials
      CredentialSources::Imds.resolve
    rescue ex
      raise "no AWS credentials found (#{ex.message}). Provide AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, install the AWS CLI, or run with an IAM role"
    end

    def self.from_json(body : String, source : String) : ResolvedCredentials
      json = JSON.parse(body)
      access_key = json["AccessKeyId"]?.try(&.as_s?)
      secret_key = json["SecretAccessKey"]?.try(&.as_s?)

      unless access_key && secret_key
        raise "#{source} returned incomplete credentials"
      end

      creds = new(
        access_key_id: access_key,
        secret_access_key: secret_key,
        session_token: json["SessionToken"]?.try(&.as_s?) || json["Token"]?.try(&.as_s?),
      )

      expires_at = json["Expiration"]?.try(&.as_s?).try do |value|
        Time.parse_rfc3339(value)
      rescue ex
        Log.warn(exception: ex) { "failed to parse credential expiration: #{value}" }
        nil
      end

      ResolvedCredentials.new(credentials: creds, expires_at: expires_at)
    end

    # Reads region from ~/.aws/config for the given profile.
    def self.region_from_profile(profile : String) : String?
      config_path = File.join(aws_config_dir, "config")
      return unless File.exists?(config_path)

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

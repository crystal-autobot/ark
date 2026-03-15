require "./ark"

module Ark
  def self.main : Nil
    config = Config.load

    Log.setup do |log_config|
      backend = Log::IOBackend.new(formatter: Log::ShortFormat)
      log_config.bind("*", Config.parse_log_level(config.log_level), backend)
    end

    provider = build_credential_provider(config)

    # Profile may override region if not explicitly set via AWS_REGION
    region = config.aws_region
    if (profile = config.aws_profile) && !ENV["AWS_REGION"]?.presence
      region = AWS::Credentials.region_from_profile(profile) || region
    end

    agent = Bedrock::Agent.new(
      agent_id: config.bedrock_agent_id,
      alias_id: config.bedrock_agent_alias_id,
      region: region,
      provider: provider,
    )

    slack_api = Slack::Client.new(config.slack_bot_token)
    socket_mode = Slack::SocketMode.new(config.slack_app_token)

    publisher : AWS::EventPublisher = if stream = config.firehose_stream_name
      AWS::FirehosePublisher.new(stream, region, provider)
    else
      Log.info { "firehose disabled (FIREHOSE_STREAM_NAME not set)" }
      AWS::NullPublisher.new
    end

    gateway = Gateway.new(
      slack_api: slack_api,
      socket_mode: socket_mode,
      agent: agent,
      publisher: publisher,
      bot_token: config.slack_bot_token,
      session_ttl: config.session_ttl_minutes.minutes,
    )

    Log.info { "starting ark region=#{region} agent=#{config.bedrock_agent_id}" }

    shutdown = Channel(Nil).new

    {% for signal in [:INT, :TERM] %}
      Signal::{{ signal.id }}.trap { shutdown.send(nil) }
    {% end %}

    spawn { gateway.run }

    shutdown.receive
    gateway.stop
    Log.info { "shutdown complete" }
  end

  private def self.build_credential_provider(config : Config) : AWS::CredentialProvider
    resolved = AWS::Credentials.resolve(config)

    if resolved.expires_at
      AWS::RefreshableCredentialProvider.new(resolved, -> { AWS::Credentials.resolve(config) })
    else
      AWS::StaticCredentialProvider.new(resolved.credentials)
    end
  end
end

Ark.main

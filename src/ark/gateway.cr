require "http/client"

module Ark
  class Gateway
    MAX_CONCURRENT_REQUESTS   =  10
    THREAD_REPLIES_LIMIT      = 200
    DEFAULT_SESSION_TTL       = 55.minutes
    SESSION_CLEANUP_THRESHOLD = 1000

    def initialize(
      @slack_api : Slack::SlackAPI,
      @socket_mode : Slack::SocketMode,
      @agent : Bedrock::AgentInvoker,
      @publisher : AWS::EventPublisher,
      @bot_token : String,
      @session_ttl : Time::Span = DEFAULT_SESSION_TTL,
    )
      @bot_user_id = ""
      @users = {} of String => Hash(String, String)
      @sessions = {} of String => Time
      @semaphore = Channel(Nil).new(MAX_CONCURRENT_REQUESTS)
      MAX_CONCURRENT_REQUESTS.times { @semaphore.send(nil) }
    end

    def run : Nil
      @bot_user_id = @slack_api.auth_test
      Log.info { "resolved bot identity: #{@bot_user_id}" }

      @socket_mode.run do |payload|
        handle_events_api(payload)
      end
    end

    def stop : Nil
      @socket_mode.stop
    end

    private def handle_events_api(payload : JSON::Any) : Nil
      event = payload.dig?("event")
      return unless event

      event_type = event["type"]?.try(&.as_s?)
      case event_type
      when "message"
        handle_message(event)
      when "app_mention"
        handle_mention(event)
      end
    end

    private def handle_message(event : JSON::Any) : Nil
      return unless valid_dm?(event)

      user = event["user"].as_s
      channel = event["channel"].as_s
      ts = event["ts"].as_s
      thread_ts = thread_timestamp(event["thread_ts"]?.try(&.as_s?), ts)

      text = (event["text"]?.try(&.as_s?) || "").strip
      slack_files = event["files"]?.try(&.as_a)
      has_files = slack_files && !slack_files.empty?

      return if text.empty? && !has_files

      files = slack_files && has_files ? download_slack_files(slack_files) : [] of Bedrock::InputFile

      spawn { @slack_api.add_reaction(channel, ts, Slack::REACTION_PROCESSING) }

      spawn { throttled_respond(user, channel, text, thread_ts, thread_ts, files) }
    end

    private def valid_dm?(event : JSON::Any) : Bool
      user = event["user"]?.try(&.as_s?)
      return false unless user && user != @bot_user_id

      sub_type = event["subtype"]?.try(&.as_s?)
      return false if sub_type && sub_type != "file_share"

      channel_type = event["channel_type"]?.try(&.as_s?)
      return false unless channel_type == Slack::CHANNEL_TYPE_DM

      event["channel"]?.try(&.as_s?) != nil && event["ts"]?.try(&.as_s?) != nil
    end

    private def handle_mention(event : JSON::Any) : Nil
      user = event["user"]?.try(&.as_s?) || return
      return if user == @bot_user_id

      channel = event["channel"]?.try(&.as_s?) || return
      ts = event["ts"]?.try(&.as_s?) || return
      thread_ts = thread_timestamp(event["thread_ts"]?.try(&.as_s?), ts)

      text = Slack::Mrkdwn.strip_mentions(event["text"]?.try(&.as_s?) || "")
      return if text.empty?

      spawn { @slack_api.add_reaction(channel, ts, Slack::REACTION_PROCESSING) }

      spawn { throttled_respond(user, channel, text, thread_ts, thread_ts, [] of Bedrock::InputFile) }
    end

    private def throttled_respond(
      user_id : String,
      channel : String,
      text : String,
      thread_ts : String,
      session_id : String,
      files : Array(Bedrock::InputFile),
    ) : Nil
      select
      when @semaphore.receive
        begin
          respond(user_id, channel, text, thread_ts, session_id, files)
        ensure
          @semaphore.send(nil)
        end
      else
        Log.warn { "request dropped: concurrency limit reached user=#{user_id}" }
        @slack_api.post_message(channel, Slack::BUSY_REPLY_TEXT, thread_ts)
      end
    end

    private def respond(
      user_id : String,
      channel : String,
      text : String,
      thread_ts : String,
      session_id : String,
      files : Array(Bedrock::InputFile),
    ) : Nil
      Log.info { "processing message user=#{user_id} channel=#{channel} thread=#{thread_ts} files=#{files.size}" }

      input_text = session_stale?(session_id) ? inject_thread_context(channel, thread_ts, text) : text
      result = @agent.invoke(input_text, session_id, user_attrs(user_id), files)
      touch_session(session_id)

      spawn { @publisher.publish(AWS::AnalyticsEvent.new(user_id, thread_ts, text, result.text)) }

      post_response(channel, thread_ts, result)

      result.files.each do |file|
        @slack_api.upload_file(channel, thread_ts, file.name, file.data)
      end
    rescue ex
      Log.error(exception: ex) { "agent invoke failed user=#{user_id} channel=#{channel}" }
      @slack_api.post_message(channel, Slack::ERROR_REPLY_TEXT, thread_ts)
    end

    private def post_response(channel : String, thread_ts : String, result : Bedrock::AgentResponse) : Nil
      segments, has_table = Slack::BlockKit.parse_segments(result.text)

      if has_table
        blocks = Slack::BlockKit.build_response_blocks(segments, result.sources)
        @slack_api.post_blocks(channel, blocks, result.text, thread_ts)
      else
        response = Slack::Mrkdwn.convert(result.text)
        response += Slack::Mrkdwn.format_sources(result.sources) unless result.sources.empty?
        @slack_api.post_message(channel, response, thread_ts)
      end
    end

    private def thread_timestamp(thread_ts : String?, message_ts : String) : String
      thread_ts && !thread_ts.empty? ? thread_ts : message_ts
    end

    private def user_attrs(user_id : String) : Hash(String, String)
      return @users[user_id] if @users.has_key?(user_id)

      info = @slack_api.get_user_info(user_id)
      attrs = info.to_attrs
      @users[user_id] = attrs
      attrs
    end

    private def session_stale?(session_id : String) : Bool
      last_used = @sessions[session_id]?
      return true unless last_used
      Time.utc - last_used > @session_ttl
    end

    private def touch_session(session_id : String) : Nil
      @sessions[session_id] = Time.utc
      evict_stale_sessions if @sessions.size > SESSION_CLEANUP_THRESHOLD
    end

    private def evict_stale_sessions : Nil
      cutoff = Time.utc - @session_ttl * 2
      @sessions.reject! { |_, last_used| last_used < cutoff }
    end

    private def inject_thread_context(channel : String, thread_ts : String, text : String) : String
      replies = @slack_api.get_thread_replies(channel, thread_ts, THREAD_REPLIES_LIMIT)
      context = Slack::ThreadContext.format(replies, @bot_user_id)
      if context
        Log.info { "restoring thread context channel=#{channel} thread=#{thread_ts} replies=#{replies.size} context_size=#{context.size}" }
        "#{context}\n\n#{text}"
      else
        text
      end
    rescue ex
      Log.warn(exception: ex) { "failed to fetch thread context channel=#{channel} thread=#{thread_ts}" }
      text
    end

    private def download_slack_files(slack_files : Array(JSON::Any)) : Array(Bedrock::InputFile)
      files = [] of Bedrock::InputFile

      slack_files.each_with_index do |slack_file, index|
        break if index >= Slack::MAX_INPUT_FILES

        name = slack_file["name"]?.try(&.as_s?) || "file"
        size = slack_file["size"]?.try(&.as_i?) || 0
        mime = slack_file["mimetype"]?.try(&.as_s?)
        url = slack_file["url_private_download"]?.try(&.as_s?)

        if size > Slack::MAX_INPUT_FILE_SIZE
          Log.warn { "skipping oversized file: #{name} (#{size} bytes)" }
          next
        end

        media_type = Slack.resolve_media_type(mime, name)
        unless media_type
          Log.warn { "unsupported file type: #{name} (#{mime})" }
          next
        end

        unless url
          Log.warn { "no download URL for file: #{name}" }
          next
        end

        data = fetch_file_bytes(url)
        next unless data

        files << Bedrock::InputFile.new(name: name, media_type: media_type, data: data)
      end

      files
    end

    private def fetch_file_bytes(url : String) : Bytes?
      uri = URI.parse(url)
      unless uri.scheme == "https" && uri.host.try(&.ends_with?(".slack.com"))
        Log.warn { "file download rejected: not a slack HTTPS URL" }
        return nil
      end

      client = HTTP::Client.new(uri)
      client.read_timeout = Slack::FILE_DOWNLOAD_TIMEOUT

      headers = HTTP::Headers{"Authorization" => "Bearer #{@bot_token}"}
      resp = client.get(uri.request_target, headers: headers)

      unless resp.success?
        Log.warn { "file download failed: #{resp.status_code}" }
        return nil
      end

      data = resp.body.to_slice
      if data.size > Slack::MAX_INPUT_FILE_SIZE
        Log.warn { "downloaded file exceeds size limit: #{data.size}" }
        return nil
      end

      data
    rescue ex
      Log.warn(exception: ex) { "file download error" }
      nil
    end
  end
end

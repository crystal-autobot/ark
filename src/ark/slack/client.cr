require "json"
require "http/client"

module Ark::Slack
  struct UserInfo
    getter name : String?
    getter timezone : String?
    getter title : String?

    def initialize(@name : String? = nil, @timezone : String? = nil, @title : String? = nil)
    end

    def to_attrs : Hash(String, String)
      attrs = {} of String => String
      name.try { |val| attrs["user_name"] = val }
      timezone.try { |val| attrs["user_timezone"] = val }
      title.try { |val| attrs["user_title"] = val }
      attrs
    end
  end

  abstract class SlackAPI
    abstract def auth_test : String
    abstract def add_reaction(channel : String, timestamp : String, emoji : String) : Nil
    abstract def post_message(channel : String, text : String, thread_ts : String? = nil) : Nil
    abstract def post_blocks(channel : String, blocks : Array(JSON::Any), fallback_text : String, thread_ts : String? = nil) : Nil
    abstract def get_user_info(user_id : String) : UserInfo
    abstract def upload_file(channel : String, thread_ts : String, name : String, data : Bytes) : Nil
  end

  class Client < SlackAPI
    API_BASE = "https://slack.com/api"

    def initialize(@bot_token : String)
    end

    def auth_test : String
      resp = api_post("auth.test")
      json = parse_response(resp)
      json["user_id"].as_s
    end

    def add_reaction(channel : String, timestamp : String, emoji : String) : Nil
      api_post("reactions.add", {
        "channel"   => channel,
        "timestamp" => timestamp,
        "name"      => emoji,
      })
      nil
    rescue ex
      Log.warn(exception: ex) { "failed to add reaction" }
    end

    def post_message(channel : String, text : String, thread_ts : String? = nil) : Nil
      parts = Mrkdwn.split_message(text)
      parts.each do |part|
        body = {"channel" => channel, "text" => part} of String => String
        body["thread_ts"] = thread_ts if thread_ts
        resp = api_post("chat.postMessage", body)
        check_response(resp, "chat.postMessage")
      end
    end

    def post_blocks(
      channel : String,
      blocks : Array(JSON::Any),
      fallback_text : String,
      thread_ts : String? = nil,
    ) : Nil
      body = {
        "channel" => JSON::Any.new(channel),
        "text"    => JSON::Any.new(fallback_text),
        "blocks"  => JSON::Any.new(blocks),
      } of String => JSON::Any
      body["thread_ts"] = JSON::Any.new(thread_ts) if thread_ts

      resp = api_post_json("chat.postMessage", body.to_json)
      check_response(resp, "chat.postMessage")
    end

    def get_user_info(user_id : String) : UserInfo
      resp = api_get("users.info", {"user" => user_id})
      json = parse_response(resp)
      user = json["user"]

      UserInfo.new(
        name: user["real_name"]?.try(&.as_s?),
        timezone: user["tz"]?.try(&.as_s?),
        title: user.dig?("profile", "title").try(&.as_s?),
      )
    rescue ex
      Log.warn(exception: ex) { "failed to get user info: #{user_id}" }
      UserInfo.new
    end

    def upload_file(channel : String, thread_ts : String, name : String, data : Bytes) : Nil
      # Step 1: get upload URL
      resp = api_get("files.getUploadURLExternal", {
        "filename" => name,
        "length"   => data.size.to_s,
      })
      json = parse_response(resp)
      upload_url = json["upload_url"].as_s
      file_id = json["file_id"].as_s

      # Step 2: upload file content
      HTTP::Client.post(upload_url, body: data)

      # Step 3: complete upload
      api_post_json("files.completeUploadExternal", {
        "files"      => [{"id" => file_id}],
        "channel_id" => channel,
        "thread_ts"  => thread_ts,
      }.to_json)
    rescue ex
      Log.error(exception: ex) { "failed to upload file: #{name}" }
    end

    private def api_post(method : String, body : Hash(String, String)? = nil) : HTTP::Client::Response
      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@bot_token}",
        "Content-Type"  => "application/json; charset=utf-8",
      }
      HTTP::Client.post(
        "#{API_BASE}/#{method}",
        headers: headers,
        body: (body || {} of String => String).to_json,
      )
    end

    private def api_post_json(method : String, body : String) : HTTP::Client::Response
      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@bot_token}",
        "Content-Type"  => "application/json; charset=utf-8",
      }
      HTTP::Client.post("#{API_BASE}/#{method}", headers: headers, body: body)
    end

    private def api_get(method : String, params : Hash(String, String)) : HTTP::Client::Response
      query = URI::Params.encode(params)
      headers = HTTP::Headers{"Authorization" => "Bearer #{@bot_token}"}
      HTTP::Client.get("#{API_BASE}/#{method}?#{query}", headers: headers)
    end

    private def parse_response(resp : HTTP::Client::Response) : JSON::Any
      json = JSON.parse(resp.body)
      unless json["ok"]?.try(&.as_bool?)
        error = json["error"]?.try(&.as_s?) || "unknown"
        raise "slack API error: #{error}"
      end
      json
    end

    private def check_response(resp : HTTP::Client::Response, method : String) : Nil
      json = JSON.parse(resp.body)
      unless json["ok"]?.try(&.as_bool?)
        error = json["error"]?.try(&.as_s?) || "unknown"
        raise "slack #{method} failed: #{error}"
      end
    end
  end
end

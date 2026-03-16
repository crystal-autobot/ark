require "../spec_helper"

# Test doubles

class MockSlackAPI < Ark::Slack::SlackAPI
  getter reactions = [] of {String, String, String}
  getter messages = [] of {String, String, String?}
  getter block_messages = [] of {String, Array(JSON::Any), String, String?}
  getter uploaded_files = [] of {String, String, String, Bytes}
  getter user_info_calls = [] of String

  property bot_user_id = "UBOT"
  property user_info_result = Ark::Slack::UserInfo.new

  def auth_test : String
    @bot_user_id
  end

  def add_reaction(channel : String, timestamp : String, emoji : String) : Nil
    @reactions << {channel, timestamp, emoji}
  end

  def post_message(channel : String, text : String, thread_ts : String? = nil) : Nil
    @messages << {channel, text, thread_ts}
  end

  def post_blocks(channel : String, blocks : Array(JSON::Any), fallback_text : String, thread_ts : String? = nil) : Nil
    @block_messages << {channel, blocks, fallback_text, thread_ts}
  end

  def get_user_info(user_id : String) : Ark::Slack::UserInfo
    @user_info_calls << user_id
    @user_info_result
  end

  def upload_file(channel : String, thread_ts : String, name : String, data : Bytes) : Nil
    @uploaded_files << {channel, thread_ts, name, data}
  end

  property thread_replies = [] of JSON::Any
  property thread_replies_should_raise = false

  def get_thread_replies(channel : String, ts : String, limit : Int32) : Array(JSON::Any)
    raise "thread fetch error" if @thread_replies_should_raise
    @thread_replies
  end
end

class MockAgent < Ark::Bedrock::AgentInvoker
  getter invocations = [] of {String, String, Hash(String, String), Array(Ark::Bedrock::InputFile)}
  property result = Ark::Bedrock::AgentResponse.new(text: "ok")
  property should_raise = false

  def invoke(
    input_text : String,
    session_id : String,
    user_attrs : Hash(String, String),
    files : Array(Ark::Bedrock::InputFile),
  ) : Ark::Bedrock::AgentResponse
    @invocations << {input_text, session_id, user_attrs, files}
    raise "agent error" if @should_raise
    @result
  end
end

class MockPublisher < Ark::AWS::EventPublisher
  getter events = [] of Ark::AWS::AnalyticsEvent

  def publish(event : Ark::AWS::AnalyticsEvent) : Nil
    @events << event
  end
end

class MockSocketMode < Ark::Slack::SocketMode
  @handler : (JSON::Any ->)?

  def initialize
    super("xapp-fake")
  end

  def run(&handler : JSON::Any ->) : Nil
    @handler = handler
  end

  def simulate_event(payload : JSON::Any) : Nil
    @handler.try(&.call(payload))
  end
end

private def build_gateway
  slack_api = MockSlackAPI.new
  socket_mode = MockSocketMode.new
  agent = MockAgent.new
  publisher = MockPublisher.new

  gateway = Ark::Gateway.new(
    slack_api: slack_api,
    socket_mode: socket_mode,
    agent: agent,
    publisher: publisher,
    bot_token: "xoxb-fake",
  )

  # Trigger auth_test to set bot_user_id
  gateway.run

  {gateway, slack_api, socket_mode, agent, publisher}
end

private def dm_event(user : String, text : String, ts : String = "1234.5678", thread_ts : String? = nil) : JSON::Any
  event = {
    "type"         => JSON::Any.new("message"),
    "user"         => JSON::Any.new(user),
    "text"         => JSON::Any.new(text),
    "channel"      => JSON::Any.new("D123"),
    "channel_type" => JSON::Any.new("im"),
    "ts"           => JSON::Any.new(ts),
  } of String => JSON::Any
  event["thread_ts"] = JSON::Any.new(thread_ts) if thread_ts
  JSON::Any.new({"event" => JSON::Any.new(event)})
end

private def thread_message(user : String, text : String) : JSON::Any
  JSON::Any.new({
    "user" => JSON::Any.new(user),
    "text" => JSON::Any.new(text),
  } of String => JSON::Any)
end

private def mention_event(user : String, text : String, ts : String = "1234.5678", channel : String = "C123") : JSON::Any
  event = {
    "type"    => JSON::Any.new("app_mention"),
    "user"    => JSON::Any.new(user),
    "text"    => JSON::Any.new(text),
    "channel" => JSON::Any.new(channel),
    "ts"      => JSON::Any.new(ts),
  } of String => JSON::Any
  JSON::Any.new({"event" => JSON::Any.new(event)})
end

describe Ark::Gateway do
  describe "DM handling" do
    it "responds to direct messages" do
      _, slack_api, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(dm_event("U999", "hello"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][0].should eq("hello")
      slack_api.messages.size.should eq(1)
      slack_api.messages[0][0].should eq("D123")
    end

    it "ignores bot's own messages" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(dm_event("UBOT", "hello"))
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end

    it "ignores non-DM messages" do
      event_data = {
        "type"         => JSON::Any.new("message"),
        "user"         => JSON::Any.new("U999"),
        "text"         => JSON::Any.new("hello"),
        "channel"      => JSON::Any.new("C123"),
        "channel_type" => JSON::Any.new("channel"),
        "ts"           => JSON::Any.new("1234.5678"),
      } of String => JSON::Any
      payload = JSON::Any.new({"event" => JSON::Any.new(event_data)})

      _, _, socket_mode, agent, _ = build_gateway
      socket_mode.simulate_event(payload)
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end

    it "ignores empty messages without files" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(dm_event("U999", ""))
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end

    it "ignores subtypes other than file_share" do
      event_data = {
        "type"         => JSON::Any.new("message"),
        "subtype"      => JSON::Any.new("message_changed"),
        "user"         => JSON::Any.new("U999"),
        "text"         => JSON::Any.new("hello"),
        "channel"      => JSON::Any.new("D123"),
        "channel_type" => JSON::Any.new("im"),
        "ts"           => JSON::Any.new("1234.5678"),
      } of String => JSON::Any
      payload = JSON::Any.new({"event" => JSON::Any.new(event_data)})

      _, _, socket_mode, agent, _ = build_gateway
      socket_mode.simulate_event(payload)
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end

    it "uses thread_ts as session ID when present" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(dm_event("U999", "hello", ts: "1.1", thread_ts: "0.9"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][1].should eq("0.9")
    end

    it "uses message ts as session ID when no thread_ts" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(dm_event("U999", "hello", ts: "1.1"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][1].should eq("1.1")
    end
  end

  describe "mention handling" do
    it "responds to app mentions" do
      _, slack_api, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(mention_event("U999", "<@UBOT> hello"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][0].should eq("hello")
    end

    it "ignores empty mentions after stripping" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(mention_event("U999", "<@UBOT>"))
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end

    it "ignores bot's own mentions" do
      _, _, socket_mode, agent, _ = build_gateway

      socket_mode.simulate_event(mention_event("UBOT", "<@UBOT> hello"))
      2.times { Fiber.yield }

      agent.invocations.should be_empty
    end
  end

  describe "error handling" do
    it "posts error message on agent failure" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.should_raise = true

      socket_mode.simulate_event(dm_event("U999", "hello"))
      2.times { Fiber.yield }

      slack_api.messages.any? { |m| m[1] == Ark::Slack::ERROR_REPLY_TEXT }.should be_true
    end
  end

  describe "file uploads" do
    it "uploads agent output files" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(
        text: "here is your chart",
        files: [
          Ark::Bedrock::AgentFile.new(name: "chart.png", media_type: "image/png", data: "PNG".to_slice),
        ],
      )

      socket_mode.simulate_event(dm_event("U999", "generate a chart"))
      2.times { Fiber.yield }

      slack_api.uploaded_files.size.should eq(1)
      slack_api.uploaded_files[0][2].should eq("chart.png")
    end

    it "deduplicates files with the same name" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(
        text: "here is your chart",
        files: [
          Ark::Bedrock::AgentFile.new(name: "chart.png", media_type: "image/png", data: "PNG1".to_slice),
          Ark::Bedrock::AgentFile.new(name: "chart.png", media_type: "image/png", data: "PNG2".to_slice),
        ],
      )

      socket_mode.simulate_event(dm_event("U999", "generate a chart"))
      2.times { Fiber.yield }

      slack_api.uploaded_files.size.should eq(1)
      slack_api.uploaded_files[0][2].should eq("chart.png")
    end

    it "uploads multiple distinct files" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(
        text: "here are your files",
        files: [
          Ark::Bedrock::AgentFile.new(name: "chart.png", media_type: "image/png", data: "PNG".to_slice),
          Ark::Bedrock::AgentFile.new(name: "data.csv", media_type: "text/csv", data: "a,b".to_slice),
        ],
      )

      socket_mode.simulate_event(dm_event("U999", "generate files"))
      2.times { Fiber.yield }

      slack_api.uploaded_files.size.should eq(2)
      slack_api.uploaded_files[0][2].should eq("chart.png")
      slack_api.uploaded_files[1][2].should eq("data.csv")
    end
  end

  describe "response formatting" do
    it "skips posting when response text is empty" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(text: "")

      socket_mode.simulate_event(dm_event("U999", "hello"))
      2.times { Fiber.yield }

      slack_api.messages.should be_empty
      slack_api.block_messages.should be_empty
    end

    it "posts blocks when response contains tables" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(
        text: "intro\n| A | B |\n| 1 | 2 |\noutro"
      )

      socket_mode.simulate_event(dm_event("U999", "hello"))
      2.times { Fiber.yield }

      slack_api.block_messages.size.should eq(1)
    end

    it "appends sources to plain text response" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      agent.result = Ark::Bedrock::AgentResponse.new(
        text: "answer",
        sources: ["doc.pdf"],
      )

      socket_mode.simulate_event(dm_event("U999", "hello"))
      2.times { Fiber.yield }

      slack_api.messages.size.should eq(1)
      slack_api.messages[0][1].should contain("Sources")
      slack_api.messages[0][1].should contain("doc.pdf")
    end
  end

  describe "user attributes" do
    it "caches user info lookups" do
      _, slack_api, socket_mode, _, _ = build_gateway

      socket_mode.simulate_event(dm_event("U999", "one"))
      2.times { Fiber.yield }
      socket_mode.simulate_event(dm_event("U999", "two"))
      2.times { Fiber.yield }

      slack_api.user_info_calls.size.should eq(1)
    end
  end

  describe "thread context restoration" do
    it "injects context on first message in thread (session unknown)" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies = [
        thread_message("U999", "earlier question"),
        thread_message("UBOT", "earlier answer"),
        thread_message("U999", "follow up"),
      ]

      socket_mode.simulate_event(dm_event("U999", "follow up", ts: "3.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      input = agent.invocations[0][0]
      input.should contain("[Previous conversation context]")
      input.should contain("User (U999): earlier question")
      input.should contain("Assistant: earlier answer")
      input.should contain("[End of previous context]")
      input.should contain("follow up")
    end

    it "does not inject context on subsequent message (session warm)" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies = [
        thread_message("U999", "first"),
        thread_message("UBOT", "response"),
        thread_message("U999", "second"),
      ]

      socket_mode.simulate_event(dm_event("U999", "first", ts: "1.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      socket_mode.simulate_event(dm_event("U999", "second", ts: "2.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(2)
      agent.invocations[1][0].should eq("second")
      agent.invocations[1][0].should_not contain("[Previous conversation context]")
    end

    it "does not inject context when thread has only current message" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies = [
        thread_message("U999", "hello"),
      ]

      socket_mode.simulate_event(dm_event("U999", "hello", ts: "1.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][0].should eq("hello")
    end

    it "does not touch session on agent failure so next attempt re-injects" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies = [
        thread_message("U999", "context msg"),
        thread_message("U999", "current"),
      ]
      agent.should_raise = true

      socket_mode.simulate_event(dm_event("U999", "current", ts: "2.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.should_raise = false
      socket_mode.simulate_event(dm_event("U999", "retry", ts: "3.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(2)
      # Both attempts should have context injected since session was never touched
      agent.invocations[0][0].should contain("[Previous conversation context]")
      agent.invocations[1][0].should contain("[Previous conversation context]")
    end

    it "proceeds without context when thread fetch fails" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies_should_raise = true

      socket_mode.simulate_event(dm_event("U999", "hello", ts: "2.0", thread_ts: "1.0"))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      agent.invocations[0][0].should eq("hello")
    end

    it "injects context for app mentions in threads" do
      _, slack_api, socket_mode, agent, _ = build_gateway
      slack_api.thread_replies = [
        thread_message("U999", "context"),
        thread_message("UBOT", "prior reply"),
        thread_message("U999", "mention"),
      ]

      event = {
        "type"      => JSON::Any.new("app_mention"),
        "user"      => JSON::Any.new("U999"),
        "text"      => JSON::Any.new("<@UBOT> mention"),
        "channel"   => JSON::Any.new("C123"),
        "ts"        => JSON::Any.new("3.0"),
        "thread_ts" => JSON::Any.new("1.0"),
      } of String => JSON::Any
      socket_mode.simulate_event(JSON::Any.new({"event" => JSON::Any.new(event)}))
      2.times { Fiber.yield }

      agent.invocations.size.should eq(1)
      input = agent.invocations[0][0]
      input.should contain("[Previous conversation context]")
      input.should contain("mention")
    end
  end
end

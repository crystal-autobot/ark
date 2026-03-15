require "../../spec_helper"

private def build_message(user : String, text : String, subtype : String? = nil) : JSON::Any
  msg = {
    "user" => JSON::Any.new(user),
    "text" => JSON::Any.new(text),
  } of String => JSON::Any
  msg["subtype"] = JSON::Any.new(subtype) if subtype
  JSON::Any.new(msg)
end

private def bot_id
  "UBOT"
end

describe Ark::Slack::ThreadContext do
  describe ".format" do
    it "returns nil for empty messages" do
      result = Ark::Slack::ThreadContext.format([] of JSON::Any, bot_id)
      result.should be_nil
    end

    it "returns nil for single message (only current)" do
      messages = [build_message("U1", "current")]
      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should be_nil
    end

    it "formats mixed user and bot messages" do
      messages = [
        build_message("U1", "question"),
        build_message("UBOT", "answer"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should_not be_nil
      result = result.not_nil!

      result.should contain("User (U1): question")
      result.should contain("Assistant: answer")
      result.should_not contain("current")
    end

    it "wraps context with header and footer markers" do
      messages = [
        build_message("U1", "hello"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      lines = result.split("\n")

      lines.first.should eq("[Previous conversation context]")
      lines.last.should eq("[End of previous context]")
    end

    it "drops oldest messages when budget is exceeded" do
      messages = [
        build_message("U1", "old message"),
        build_message("U1", "recent message"),
        build_message("U1", "current"),
      ]

      # Budget enough for one formatted message but not two
      result = Ark::Slack::ThreadContext.format(messages, bot_id, budget: 30)
      result.should_not be_nil
      result = result.not_nil!

      result.should contain("recent message")
      result.should_not contain("old message")
      result.should contain("[... 1 earlier messages omitted]")
    end

    it "returns nil when no messages fit within budget" do
      messages = [
        build_message("U1", "a very long message"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id, budget: 1)
      result.should be_nil
    end

    it "truncates individual messages exceeding max length" do
      long_text = "x" * 2500
      messages = [
        build_message("U1", long_text),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      result.should contain("x" * 2000)
      result.should contain("...")
      result.should_not contain("x" * 2001)
    end

    it "filters out error reply messages" do
      messages = [
        build_message("UBOT", Ark::Slack::ERROR_REPLY_TEXT),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should be_nil
    end

    it "filters out busy reply messages" do
      messages = [
        build_message("UBOT", Ark::Slack::BUSY_REPLY_TEXT),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should be_nil
    end

    it "filters out messages with non-standard subtypes" do
      messages = [
        build_message("U1", "normal"),
        build_message("U1", "changed", subtype: "message_changed"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      result.should contain("normal")
      result.should_not contain("changed")
    end

    it "keeps messages with file_share subtype" do
      messages = [
        build_message("U1", "shared a file", subtype: "file_share"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      result.should contain("shared a file")
    end

    it "filters out messages with empty text" do
      msg = JSON::Any.new({
        "user" => JSON::Any.new("U1"),
        "text" => JSON::Any.new("   "),
      } of String => JSON::Any)

      messages = [msg, build_message("U1", "current")]
      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should be_nil
    end

    it "filters out messages without text field" do
      msg = JSON::Any.new({
        "user" => JSON::Any.new("U1"),
      } of String => JSON::Any)

      messages = [msg, build_message("U1", "current")]
      result = Ark::Slack::ThreadContext.format(messages, bot_id)
      result.should be_nil
    end

    it "labels messages without user as unknown" do
      msg = JSON::Any.new({
        "text" => JSON::Any.new("mystery"),
      } of String => JSON::Any)

      messages = [msg, build_message("U1", "current")]
      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      result.should contain("User (unknown): mystery")
    end

    it "preserves chronological order of selected messages" do
      messages = [
        build_message("U1", "first"),
        build_message("U2", "second"),
        build_message("UBOT", "third"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      first_pos = result.index("first").not_nil!
      second_pos = result.index("second").not_nil!
      third_pos = result.index("third").not_nil!

      (first_pos < second_pos).should be_true
      (second_pos < third_pos).should be_true
    end

    it "omits header line for dropped messages when none dropped" do
      messages = [
        build_message("U1", "hello"),
        build_message("U1", "current"),
      ]

      result = Ark::Slack::ThreadContext.format(messages, bot_id).not_nil!
      result.should_not contain("earlier messages omitted")
    end
  end
end

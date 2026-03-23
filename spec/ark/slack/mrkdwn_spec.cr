require "../../spec_helper"

describe Ark::Slack::Mrkdwn do
  describe ".convert" do
    it "converts bold markdown to mrkdwn" do
      Ark::Slack::Mrkdwn.convert("**hello**").should eq("*hello*")
    end

    it "converts strikethrough" do
      Ark::Slack::Mrkdwn.convert("~~removed~~").should eq("~removed~")
    end

    it "converts markdown links to Slack format" do
      Ark::Slack::Mrkdwn.convert("[click](https://example.com)").should eq("<https://example.com|click>")
    end

    it "converts headings to bold" do
      Ark::Slack::Mrkdwn.convert("## Section title").should eq("*Section title*")
    end

    it "collapses multiple blank lines" do
      Ark::Slack::Mrkdwn.convert("a\n\n\n\nb").should eq("a\n\nb")
    end

    it "handles mixed formatting" do
      input = "## Title\n\n**bold** and ~~strike~~"
      result = Ark::Slack::Mrkdwn.convert(input)
      result.should contain("*Title*")
      result.should contain("*bold*")
      result.should contain("~strike~")
    end

    it "strips leading/trailing whitespace" do
      Ark::Slack::Mrkdwn.convert("  hello  ").should eq("hello")
    end

    it "preserves content inside code blocks" do
      input = "before **bold**\n```\n**not bold**\n~~not strike~~\n```\nafter **bold**"
      result = Ark::Slack::Mrkdwn.convert(input)
      result.should contain("*bold*")
      result.should contain("**not bold**")
      result.should contain("~~not strike~~")
    end

    it "handles multiple code blocks" do
      input = "**a**\n```\n**b**\n```\n**c**\n```\n**d**\n```\n**e**"
      result = Ark::Slack::Mrkdwn.convert(input)
      result.should contain("*a*")
      result.should contain("**b**")
      result.should contain("*c*")
      result.should contain("**d**")
      result.should contain("*e*")
    end

    it "handles text with no code blocks" do
      Ark::Slack::Mrkdwn.convert("**bold** and ~~strike~~").should eq("*bold* and ~strike~")
    end
  end

  describe ".sanitize" do
    it "escapes <!channel> broadcast" do
      Ark::Slack::Mrkdwn.sanitize("alert <!channel> now").should eq("alert &lt;!channel&gt; now")
    end

    it "escapes <!here> broadcast" do
      Ark::Slack::Mrkdwn.sanitize("hey <!here>").should eq("hey &lt;!here&gt;")
    end

    it "escapes <!everyone> broadcast" do
      Ark::Slack::Mrkdwn.sanitize("<!everyone> listen").should eq("&lt;!everyone&gt; listen")
    end

    it "escapes user mentions" do
      Ark::Slack::Mrkdwn.sanitize("ask <@U1234ABC>").should eq("ask &lt;@U1234ABC&gt;")
    end

    it "escapes multiple tokens" do
      input = "<!channel> and <@U123> and <!here>"
      result = Ark::Slack::Mrkdwn.sanitize(input)
      result.should_not contain("<!channel>")
      result.should_not contain("<@U123>")
      result.should_not contain("<!here>")
    end

    it "preserves normal text" do
      Ark::Slack::Mrkdwn.sanitize("hello world").should eq("hello world")
    end
  end

  describe ".convert" do
    it "neutralizes broadcast tokens in output" do
      result = Ark::Slack::Mrkdwn.convert("Sure! <!channel> please read this")
      result.should_not contain("<!channel>")
      result.should contain("&lt;!channel&gt;")
    end

    it "neutralizes user mentions in output" do
      result = Ark::Slack::Mrkdwn.convert("Contact <@U999ZZZ> for help")
      result.should_not contain("<@U999ZZZ>")
    end
  end

  describe ".format_sources" do
    it "formats single source" do
      result = Ark::Slack::Mrkdwn.format_sources(["doc.pdf"])
      result.should eq("\n\n*Sources:*\n• doc.pdf")
    end

    it "formats multiple sources" do
      result = Ark::Slack::Mrkdwn.format_sources(["a.pdf", "b.pdf"])
      result.should contain("• a.pdf")
      result.should contain("• b.pdf")
    end
  end

  describe ".strip_mention" do
    it "strips the specified user's mention" do
      Ark::Slack::Mrkdwn.strip_mention("<@U123> hello", "U123").should eq("hello")
    end

    it "preserves other users' mentions" do
      Ark::Slack::Mrkdwn.strip_mention("<@UBOT> ask <@U456> about it", "UBOT").should eq("ask <@U456> about it")
    end

    it "handles mention-only text" do
      Ark::Slack::Mrkdwn.strip_mention("<@U123>", "U123").should eq("")
    end

    it "preserves text without mentions" do
      Ark::Slack::Mrkdwn.strip_mention("hello world", "U123").should eq("hello world")
    end
  end

  describe ".resolve_mentions" do
    it "replaces mentions with resolved names" do
      result = Ark::Slack::Mrkdwn.resolve_mentions("ask <@U123> about it") do |uid|
        uid == "U123" ? "Alice" : nil
      end
      result.should eq("ask @Alice about it")
    end

    it "leaves unresolved mentions unchanged" do
      result = Ark::Slack::Mrkdwn.resolve_mentions("ask <@U999>") do |_uid|
        nil
      end
      result.should eq("ask <@U999>")
    end

    it "resolves multiple mentions" do
      result = Ark::Slack::Mrkdwn.resolve_mentions("<@U1> and <@U2>") do |uid|
        {"U1" => "Alice", "U2" => "Bob"}[uid]?
      end
      result.should eq("@Alice and @Bob")
    end

    it "preserves text without mentions" do
      result = Ark::Slack::Mrkdwn.resolve_mentions("hello world") { |_| nil }
      result.should eq("hello world")
    end
  end

  describe ".split_message" do
    it "returns single part for short text" do
      Ark::Slack::Mrkdwn.split_message("short", 100).should eq(["short"])
    end

    it "splits at paragraph boundary" do
      text = "a" * 50 + "\n\n" + "b" * 50
      parts = Ark::Slack::Mrkdwn.split_message(text, 60)
      parts.size.should be > 1
      parts[0].should eq("a" * 50)
    end

    it "falls back to newline boundary" do
      text = "a" * 50 + "\n" + "b" * 50
      parts = Ark::Slack::Mrkdwn.split_message(text, 60)
      parts.size.should be > 1
      parts[0].should eq("a" * 50)
    end

    it "hard cuts when no boundaries exist" do
      text = "a" * 100
      parts = Ark::Slack::Mrkdwn.split_message(text, 60)
      parts.size.should eq(2)
      parts[0].size.should eq(60)
    end
  end
end

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

  describe ".strip_mentions" do
    it "strips single mention" do
      Ark::Slack::Mrkdwn.strip_mentions("<@U123> hello").should eq("hello")
    end

    it "strips multiple mentions" do
      Ark::Slack::Mrkdwn.strip_mentions("<@U123> <@U456> hello").should eq("hello")
    end

    it "handles mention-only text" do
      Ark::Slack::Mrkdwn.strip_mentions("<@U123>").should eq("")
    end

    it "preserves text without mentions" do
      Ark::Slack::Mrkdwn.strip_mentions("hello world").should eq("hello world")
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

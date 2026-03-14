require "../../spec_helper"

describe Ark::Bedrock::Session do
  describe ".sanitize_id" do
    it "replaces dots with dashes" do
      Ark::Bedrock::Session.sanitize_id("1234567890.123456").should eq("1234567890-123456")
    end

    it "handles IDs without dots" do
      Ark::Bedrock::Session.sanitize_id("abcdef").should eq("abcdef")
    end

    it "handles multiple dots" do
      Ark::Bedrock::Session.sanitize_id("a.b.c").should eq("a-b-c")
    end
  end

  describe ".prompt_attributes" do
    it "includes current_datetime" do
      attrs = Ark::Bedrock::Session.prompt_attributes
      attrs.has_key?("current_datetime").should be_true
      attrs["current_datetime"].should_not be_empty
    end

    it "returns RFC3339 formatted datetime" do
      attrs = Ark::Bedrock::Session.prompt_attributes
      # Should not raise
      Time.parse_rfc3339(attrs["current_datetime"])
    end
  end
end

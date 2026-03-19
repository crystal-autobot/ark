require "../../spec_helper"

describe Ark::Slack do
  describe ".resolve_media_type" do
    it "returns Slack MIME type when valid" do
      Ark::Slack.resolve_media_type("text/csv", "data.csv").should eq("text/csv")
    end

    it "falls back to extension for binary MIME" do
      Ark::Slack.resolve_media_type("binary", "data.csv").should eq("text/csv")
    end

    it "falls back to extension for octet-stream MIME" do
      Ark::Slack.resolve_media_type("application/octet-stream", "data.xlsx").should eq(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      )
    end

    it "falls back to extension for nil MIME" do
      Ark::Slack.resolve_media_type(nil, "doc.pdf").should eq("application/pdf")
    end

    it "returns nil for unsupported extension" do
      Ark::Slack.resolve_media_type(nil, "file.xyz").should be_nil
    end

    it "handles case-insensitive extensions" do
      Ark::Slack.resolve_media_type(nil, "FILE.PDF").should eq("application/pdf")
    end

    it "maps all expected extensions" do
      {
        ".csv"  => "text/csv",
        ".json" => "application/json",
        ".yaml" => "text/yaml",
        ".yml"  => "text/yaml",
        ".html" => "text/html",
        ".md"   => "text/markdown",
        ".txt"  => "text/plain",
        ".pdf"  => "application/pdf",
      }.each do |ext, mime|
        Ark::Slack.resolve_media_type(nil, "file#{ext}").should eq(mime)
      end
    end

    it "rejects image files by extension" do
      Ark::Slack.resolve_media_type(nil, "photo.png").should be_nil
      Ark::Slack.resolve_media_type(nil, "photo.jpg").should be_nil
    end

    it "rejects image files by Slack MIME type" do
      Ark::Slack.resolve_media_type("image/png", "photo.png").should be_nil
      Ark::Slack.resolve_media_type("image/jpeg", "photo.jpg").should be_nil
      Ark::Slack.resolve_media_type("image/gif", "animation.gif").should be_nil
    end

    it "prefers extension mapping over Slack MIME" do
      Ark::Slack.resolve_media_type("application/csv", "data.csv").should eq("text/csv")
    end
  end
end

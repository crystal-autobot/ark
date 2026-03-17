require "../../spec_helper"

describe Ark::Slack::BlockKit do
  describe ".table_line?" do
    it "detects table lines" do
      Ark::Slack::BlockKit.table_line?("| A | B |").should be_true
    end

    it "detects separator lines" do
      Ark::Slack::BlockKit.table_line?("| --- | --- |").should be_true
    end

    it "rejects non-table lines" do
      Ark::Slack::BlockKit.table_line?("plain text").should be_false
    end

    it "rejects lines starting but not ending with pipe" do
      Ark::Slack::BlockKit.table_line?("| only start").should be_false
    end
  end

  describe ".parse_segments" do
    it "returns no table for plain text" do
      segments, has_table = Ark::Slack::BlockKit.parse_segments("hello world")
      has_table.should be_false
      segments.size.should eq(1)
      segments[0].table?.should be_false
    end

    it "detects table segments" do
      text = "intro\n| A | B |\n| 1 | 2 |\noutro"
      segments, has_table = Ark::Slack::BlockKit.parse_segments(text)
      has_table.should be_true
      segments.size.should eq(3)
      segments[0].table?.should be_false
      segments[1].table?.should be_true
      segments[2].table?.should be_false
    end

    it "handles table-only text" do
      text = "| A | B |\n| 1 | 2 |"
      segments, has_table = Ark::Slack::BlockKit.parse_segments(text)
      has_table.should be_true
      segments.size.should eq(1)
      segments[0].table?.should be_true
    end
  end

  describe ".parse_markdown_table" do
    it "parses header and data rows" do
      text = "| Name | Age |\n| --- | --- |\n| Alice | 30 |"
      rows = Ark::Slack::BlockKit.parse_markdown_table(text)
      rows.size.should eq(2)
      rows[0].should eq(["Name", "Age"])
      rows[1].should eq(["Alice", "30"])
    end

    it "skips separator lines" do
      text = "| A |\n| --- |\n| B |"
      rows = Ark::Slack::BlockKit.parse_markdown_table(text)
      rows.size.should eq(2)
    end

    it "returns empty for blank text" do
      Ark::Slack::BlockKit.parse_markdown_table("").should be_empty
    end
  end

  describe ".build_response_blocks" do
    it "builds section blocks for prose" do
      segments = [Ark::Slack::BlockKit::TextSegment.new("hello world", false)]
      blocks = Ark::Slack::BlockKit.build_response_blocks(segments, [] of String)
      blocks.size.should eq(1)
      blocks[0]["type"].as_s.should eq("section")
    end

    it "builds table blocks for table segments" do
      segments = [Ark::Slack::BlockKit::TextSegment.new("| A | B |\n| 1 | 2 |", true)]
      blocks = Ark::Slack::BlockKit.build_response_blocks(segments, [] of String)
      blocks.size.should eq(1)
      blocks[0]["type"].as_s.should eq("table")
      blocks[0]["rows"].as_a.size.should eq(2)
    end

    it "strips markdown formatting from table cell text" do
      table = "| Name | Info |\n|---|---|\n| `alpha` | **bravo** value |"
      segments = [Ark::Slack::BlockKit::TextSegment.new(table, true)]
      blocks = Ark::Slack::BlockKit.build_response_blocks(segments, [] of String)

      rows = blocks[0]["rows"].as_a
      data_row = rows[1].as_a
      data_row[0]["text"].as_s.should eq("alpha")
      data_row[1]["text"].as_s.should eq("bravo value")
    end

    it "appends sources block" do
      segments = [Ark::Slack::BlockKit::TextSegment.new("text", false)]
      blocks = Ark::Slack::BlockKit.build_response_blocks(segments, ["doc.pdf"])
      blocks.size.should eq(2)
      blocks[1]["text"]["text"].as_s.should contain("Sources")
    end
  end

  describe ".render_as_code_block" do
    it "renders table as aligned preformatted block" do
      text = "| Name | Age |\n| --- | --- |\n| Alice | 30 |"
      result = Ark::Slack::BlockKit.render_as_code_block(text)
      result.should start_with("```\n")
      result.should end_with("\n```")
      result.should contain("Name")
      result.should contain("Alice")
    end

    it "strips markdown from cells" do
      text = "| Field | Value |\n|---|---|\n| `ID` | **gm3** |"
      result = Ark::Slack::BlockKit.render_as_code_block(text)
      # Extract lines between code fences
      inner = result.strip("` \n")
      inner.should contain("ID")
      inner.should contain("gm3")
      inner.should_not contain("`")
      inner.should_not contain("**")
    end

    it "aligns columns with padding" do
      text = "| A | BB |\n|---|---|\n| CCC | D |"
      result = Ark::Slack::BlockKit.render_as_code_block(text)
      lines = result.strip("```\n").split("\n")
      lines.each do |line|
        next if line == "```"
        # All lines should have same alignment
        parts = line.split(/  +/)
        parts.size.should eq(2)
      end
    end

    it "returns original text for non-table input" do
      Ark::Slack::BlockKit.render_as_code_block("").should eq("")
    end
  end

  describe ".render_with_code_block_tables" do
    it "renders tables as code blocks and prose as mrkdwn" do
      segments = [
        Ark::Slack::BlockKit::TextSegment.new("intro text", false),
        Ark::Slack::BlockKit::TextSegment.new("| A | B |\n| 1 | 2 |", true),
        Ark::Slack::BlockKit::TextSegment.new("outro text", false),
      ]
      result = Ark::Slack::BlockKit.render_with_code_block_tables(segments)
      result.should contain("intro text")
      result.should contain("```\n")
      result.should contain("outro text")
    end

    it "converts prose markdown to mrkdwn" do
      segments = [
        Ark::Slack::BlockKit::TextSegment.new("**bold** text", false),
        Ark::Slack::BlockKit::TextSegment.new("| A | B |\n| 1 | 2 |", true),
      ]
      result = Ark::Slack::BlockKit.render_with_code_block_tables(segments)
      result.should contain("*bold* text")
    end
  end
end

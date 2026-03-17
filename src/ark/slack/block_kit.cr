require "json"

module Ark::Slack::BlockKit
  SEPARATOR_RE = /^\s*\|[\s\-:|]+\|\s*$/

  struct TextSegment
    getter content : String
    getter? table : Bool

    def initialize(@content : String, @table : Bool)
    end
  end

  # Splits text into alternating prose and table segments.
  # Returns segments and whether any tables were found.
  def self.parse_segments(text : String) : {Array(TextSegment), Bool}
    lines = text.split('\n')
    segments = [] of TextSegment
    buf = String::Builder.new
    in_table = false
    has_table = false

    lines.each do |line|
      is_table = table_line?(line)

      if is_table != in_table && buf.bytesize > 0
        segments << TextSegment.new(buf.to_s, in_table)
        buf = String::Builder.new
      end

      in_table = is_table
      has_table = true if is_table

      buf << '\n' if buf.bytesize > 0
      buf << line
    end

    if buf.bytesize > 0
      segments << TextSegment.new(buf.to_s, in_table)
    end

    {segments, has_table}
  end

  def self.table_line?(line : String) : Bool
    trimmed = line.strip
    trimmed.starts_with?('|') && trimmed.ends_with?('|')
  end

  # Parses markdown table text into rows of cell strings.
  def self.parse_markdown_table(text : String) : Array(Array(String))
    rows = [] of Array(String)

    text.split('\n').each do |line|
      line = line.strip
      next if line.empty? || SEPARATOR_RE.matches?(line)

      line = line.strip('|')
      cells = line.split('|').map(&.strip)
      rows << cells unless cells.empty?
    end

    rows
  end

  # Builds Slack Block Kit JSON blocks from segments and sources.
  def self.build_response_blocks(
    segments : Array(TextSegment),
    sources : Array(String),
  ) : Array(JSON::Any)
    blocks = [] of JSON::Any

    segments.each do |seg|
      if seg.table?
        rows = parse_markdown_table(seg.content)
        next if rows.empty?

        block_rows = rows.map do |row|
          JSON::Any.new(row.map { |cell|
            JSON::Any.new({"type" => JSON::Any.new("raw_text"), "text" => JSON::Any.new(Mrkdwn.strip_markdown(cell))})
          })
        end

        blocks << JSON::Any.new({
          "type" => JSON::Any.new("table"),
          "rows" => JSON::Any.new(block_rows),
        })
      else
        content = Mrkdwn.convert(seg.content)
        next if content.empty?

        blocks << section_block(content)
      end
    end

    unless sources.empty?
      blocks << section_block(Mrkdwn.format_sources(sources))
    end

    blocks
  end

  # Renders segments with tables as preformatted code blocks (fallback for Block Kit).
  def self.render_with_code_block_tables(segments : Array(TextSegment)) : String
    String.build do |buf|
      segments.each_with_index do |seg, i|
        buf << "\n" if i > 0
        if seg.table?
          buf << render_as_code_block(seg.content)
        else
          buf << Mrkdwn.convert(seg.content)
        end
      end
    end.strip
  end

  # Renders a markdown table as a preformatted, column-aligned code block.
  def self.render_as_code_block(text : String) : String
    rows = parse_markdown_table(text)
    return text if rows.empty?

    rows = rows.map { |row| row.map { |cell| Mrkdwn.strip_markdown(cell) } }

    col_count = rows.max_of(&.size)
    widths = (0...col_count).map { |i| rows.max_of { |row| (row[i]? || "").size } }

    lines = rows.map do |row|
      (0...col_count).map { |i| (row[i]? || "").ljust(widths[i]) }.join("  ")
    end

    "```\n#{lines.join("\n")}\n```"
  end

  private def self.section_block(text : String) : JSON::Any
    JSON::Any.new({
      "type" => JSON::Any.new("section"),
      "text" => JSON::Any.new({
        "type" => JSON::Any.new("mrkdwn"),
        "text" => JSON::Any.new(text),
      }),
    })
  end
end

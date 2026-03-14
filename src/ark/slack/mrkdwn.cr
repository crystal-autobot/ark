module Ark::Slack::Mrkdwn
  MENTION_RE     = /<@\w+>\s*/
  BOLD_RE        = /\*\*(.+?)\*\*/
  STRIKE_RE      = /~~(.+?)~~/
  LINK_RE        = /\[([^\]]+)\]\(([^)]+)\)/
  HEADING_RE     = Regex.new(%q(^\#{1,6}\s+([^\n]+)$), Regex::Options::MULTILINE)
  BLANK_LINES_RE = /\n{3,}/
  CODE_FENCE_RE  = /```[\s\S]*?```/

  # Slack control tokens that could trigger mass notifications or impersonate mentions.
  BROADCAST_RE    = /<!(?:channel|here|everyone)>/
  USER_MENTION_RE = /<@[A-Z0-9]+>/

  # Converts common markdown to Slack mrkdwn format, preserving code blocks.
  # Neutralizes Slack control tokens to prevent mention/broadcast injection.
  def self.convert(text : String) : String
    text = sanitize(text)
    parts = split_code_blocks(text)
    parts.map_with_index do |part, index|
      index.odd? ? part : convert_prose(part)
    end.join.strip
  end

  # Escapes Slack control tokens that could trigger notifications or impersonate users.
  def self.sanitize(text : String) : String
    text = text.gsub(BROADCAST_RE) { |match| match.gsub('<', "&lt;").gsub('>', "&gt;") }
    text.gsub(USER_MENTION_RE) { |match| match.gsub('<', "&lt;").gsub('>', "&gt;") }
  end

  # Renders source names as a bulleted list.
  def self.format_sources(sources : Array(String)) : String
    String.build do |buf|
      buf << "\n\n*Sources:*"
      sources.each do |source|
        buf << "\n• " << source
      end
    end
  end

  # Strips @mentions from message text.
  def self.strip_mentions(text : String) : String
    text.gsub(MENTION_RE, "").strip
  end

  # Splits text at paragraph boundaries if it exceeds max_len.
  def self.split_message(text : String, max_len : Int32 = MAX_MESSAGE_LEN) : Array(String)
    return [text] if text.size <= max_len

    parts = [] of String
    remaining = text

    while remaining.size > 0
      if remaining.size <= max_len
        parts << remaining
        break
      end

      cut = find_split_point(remaining, max_len)
      parts << remaining[0, cut]
      remaining = remaining[cut..].lstrip('\n')
    end

    parts
  end

  # Splits text into alternating [prose, code, prose, code, ...] segments.
  # Odd indices are code blocks (preserved as-is).
  private def self.split_code_blocks(text : String) : Array(String)
    parts = [] of String
    last_end = 0

    text.scan(CODE_FENCE_RE) do |match|
      match_start = text.index(match[0], last_end)
      next unless match_start

      parts << text[last_end...match_start]
      parts << match[0]
      last_end = match_start + match[0].size
    end

    parts << text[last_end..]
    parts
  end

  private def self.convert_prose(text : String) : String
    text = text.gsub(BOLD_RE, "*\\1*")
    text = text.gsub(STRIKE_RE, "~\\1~")
    text = text.gsub(LINK_RE, "<\\2|\\1>")
    text = text.gsub(HEADING_RE, "*\\1*")
    text.gsub(BLANK_LINES_RE, "\n\n")
  end

  private def self.find_split_point(text : String, max_len : Int32) : Int32
    cut = text[0, max_len].rindex("\n\n")
    return cut if cut && cut > 0

    cut = text[0, max_len].rindex('\n')
    return cut if cut && cut > 0

    max_len
  end
end

module Ark::Slack::Mrkdwn
  MENTION_RE     = /<@\w+>\s*/
  BOLD_RE        = /\*\*(.+?)\*\*/
  STRIKE_RE      = /~~(.+?)~~/
  LINK_RE        = /\[([^\]]+)\]\(([^)]+)\)/
  HEADING_RE     = Regex.new(%q(^\#{1,6}\s+([^\n]+)$), Regex::Options::MULTILINE)
  BLANK_LINES_RE = /\n{3,}/

  # Converts common markdown to Slack mrkdwn format.
  def self.convert(text : String) : String
    text = text.gsub(BOLD_RE, "*\\1*")
    text = text.gsub(STRIKE_RE, "~\\1~")
    text = text.gsub(LINK_RE, "<\\2|\\1>")
    text = text.gsub(HEADING_RE, "*\\1*")
    text = text.gsub(BLANK_LINES_RE, "\n\n")
    text.strip
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

  private def self.find_split_point(text : String, max_len : Int32) : Int32
    # Try double-newline first
    cut = text[0, max_len].rindex("\n\n")
    return cut if cut && cut > 0

    # Fall back to single newline
    cut = text[0, max_len].rindex('\n')
    return cut if cut && cut > 0

    # Hard cut
    max_len
  end
end

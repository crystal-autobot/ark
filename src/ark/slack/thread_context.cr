module Ark::Slack
  module ThreadContext
    DEFAULT_BUDGET     = 12_000
    MAX_MESSAGE_LENGTH =  2_000

    CONTEXT_HEADER = "[Previous conversation context]"
    CONTEXT_FOOTER = "[End of previous context]"

    def self.format(
      messages : Array(JSON::Any),
      bot_user_id : String,
      budget : Int32 = DEFAULT_BUDGET,
    ) : String?
      return nil if messages.size <= 1

      history = messages[0...-1]
      lines = history.compact_map { |msg| format_message(msg, bot_user_id) }
      return nil if lines.empty?

      select_within_budget(lines, budget)
    end

    private def self.select_within_budget(lines : Array(String), budget : Int32) : String?
      selected = [] of String
      used = 0

      lines.reverse_each do |line|
        cost = line.size + 1
        break if used + cost > budget
        selected << line
        used += cost
      end

      return nil if selected.empty?
      selected.reverse!

      dropped = lines.size - selected.size
      build_context(selected, dropped)
    end

    private def self.build_context(selected : Array(String), dropped : Int32) : String
      parts = [CONTEXT_HEADER]
      parts << "[... #{dropped} earlier messages omitted]" if dropped > 0
      parts.concat(selected)
      parts << CONTEXT_FOOTER
      parts.join("\n")
    end

    private def self.format_message(msg : JSON::Any, bot_user_id : String) : String?
      subtype = msg["subtype"]?.try(&.as_s?)
      return nil if subtype && subtype != "file_share"

      text = msg["text"]?.try(&.as_s?)
      return nil if text.nil? || text.strip.empty?
      return nil if text == ERROR_REPLY_TEXT || text == BUSY_REPLY_TEXT

      label = build_label(msg, bot_user_id)
      truncated = truncate(text, MAX_MESSAGE_LENGTH)
      "#{label}: #{truncated}"
    end

    private def self.build_label(msg : JSON::Any, bot_user_id : String) : String
      user = msg["user"]?.try(&.as_s?)
      user == bot_user_id ? "Assistant" : "User (#{user || "unknown"})"
    end

    private def self.truncate(text : String, max : Int32) : String
      text.size > max ? "#{text[0, max]}..." : text
    end
  end
end

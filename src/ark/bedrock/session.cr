module Ark::Bedrock
  module Session
    # Converts Slack thread_ts (e.g. "1234567890.123456") to a
    # Bedrock-compatible session ID by replacing dots with dashes.
    def self.sanitize_id(thread_ts : String) : String
      thread_ts.gsub('.', '-')
    end

    def self.prompt_attributes : Hash(String, String)
      {"current_datetime" => Time.utc.to_rfc3339}
    end
  end
end

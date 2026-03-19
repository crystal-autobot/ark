module Ark::Slack
  CHANNEL_TYPE_DM       = "im"
  REACTION_PROCESSING   = "eyes"
  ERROR_REPLY_TEXT      = "Sorry, I encountered an error processing your request."
  BUSY_REPLY_TEXT       = "I'm currently handling too many requests. Please try again in a moment."
  MAX_INPUT_FILES       = 5
  MAX_INPUT_FILE_SIZE   = 10 * 1024 * 1024 # 10 MB
  MAX_OUTPUT_FILE_SIZE  = 50 * 1024 * 1024 # 50 MB
  MAX_MESSAGE_LEN       = 40_000
  FILE_DOWNLOAD_TIMEOUT = 30.seconds

  MIME_BINARY       = "binary"
  MIME_OCTET_STREAM = "application/octet-stream"

  UNSUPPORTED_FILE_REPLY_TEXT = "I can't process this file type. Supported formats: CSV, PDF, Excel, Word, JSON, YAML, HTML, Markdown, and plain text."

  # Extension -> MIME type mapping for Bedrock Code Interpreter supported input types.
  # https://docs.aws.amazon.com/bedrock/latest/userguide/agents-code-interpretation.html
  EXT_MEDIA_TYPES = {
    ".csv"  => "text/csv",
    ".xls"  => "application/vnd.ms-excel",
    ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".json" => "application/json",
    ".yaml" => "text/yaml",
    ".yml"  => "text/yaml",
    ".doc"  => "application/msword",
    ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".html" => "text/html",
    ".md"   => "text/markdown",
    ".txt"  => "text/plain",
    ".pdf"  => "application/pdf",
  }

  SUPPORTED_MEDIA_TYPES = EXT_MEDIA_TYPES.values.to_set

  def self.resolve_media_type(slack_mime : String?, filename : String) : String?
    ext = File.extname(filename).downcase
    if mime = EXT_MEDIA_TYPES[ext]?
      return mime
    end

    if slack_mime && slack_mime != MIME_BINARY && slack_mime != MIME_OCTET_STREAM
      return slack_mime if SUPPORTED_MEDIA_TYPES.includes?(slack_mime)
    end

    nil
  end
end

module Ark::Slack
  CHANNEL_TYPE_DM       = "im"
  REACTION_PROCESSING   = "eyes"
  ERROR_REPLY_TEXT      = "Sorry, I encountered an error processing your request."
  MAX_INPUT_FILES       = 5
  MAX_INPUT_FILE_SIZE   = 10 * 1024 * 1024 # 10 MB
  MAX_MESSAGE_LEN       = 40_000
  FILE_DOWNLOAD_TIMEOUT = 30.seconds

  MIME_BINARY       = "binary"
  MIME_OCTET_STREAM = "application/octet-stream"

  # Extension -> MIME type mapping for Bedrock code interpreter.
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
    ".png"  => "image/png",
  }

  def self.resolve_media_type(slack_mime : String?, filename : String) : String?
    if slack_mime && slack_mime != MIME_BINARY && slack_mime != MIME_OCTET_STREAM
      return slack_mime
    end
    ext = File.extname(filename).downcase
    EXT_MEDIA_TYPES[ext]?
  end
end

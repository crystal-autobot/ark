module Ark::Bedrock
  struct InputFile
    getter name : String
    getter media_type : String
    getter data : Bytes

    def initialize(@name : String, @media_type : String, @data : Bytes)
    end
  end

  struct AgentFile
    getter name : String
    getter media_type : String
    getter data : Bytes

    def initialize(@name : String, @media_type : String, @data : Bytes)
    end
  end

  struct TraceMetadata
    getter knowledge_bases : Array(String)
    getter sources : Array(String)
    getter action_groups : Array(String)
    getter search_queries : Array(String)
    getter rationale : String?

    def initialize(
      @knowledge_bases = [] of String,
      @sources = [] of String,
      @action_groups = [] of String,
      @search_queries = [] of String,
      @rationale = nil,
    )
    end
  end

  struct AgentResponse
    getter text : String
    getter sources : Array(String)
    getter files : Array(AgentFile)
    getter trace : TraceMetadata

    def initialize(
      @text : String,
      @sources : Array(String) = [] of String,
      @files : Array(AgentFile) = [] of AgentFile,
      @trace : TraceMetadata = TraceMetadata.new,
    )
    end
  end
end

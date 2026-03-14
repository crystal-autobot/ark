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

  struct AgentResponse
    getter text : String
    getter sources : Array(String)
    getter files : Array(AgentFile)

    def initialize(@text : String, @sources : Array(String) = [] of String, @files : Array(AgentFile) = [] of AgentFile)
    end
  end
end

require "json"
require "http/client"
require "uri"

module Ark::Bedrock
  abstract class AgentInvoker
    abstract def invoke(
      input_text : String,
      session_id : String,
      user_attrs : Hash(String, String),
      files : Array(InputFile),
    ) : AgentResponse
  end

  class Agent < AgentInvoker
    ENDPOINT_PREFIX = "bedrock-agent-runtime"
    SIGNING_SERVICE = "bedrock"
    CONNECT_TIMEOUT = 30.seconds
    READ_TIMEOUT    = 300.seconds

    def initialize(
      @agent_id : String,
      @alias_id : String,
      @region : String,
      @provider : AWS::CredentialProvider,
      @enable_trace : Bool = false,
    )
      @signer = AWS::Signer.new(SIGNING_SERVICE, @region, @provider)
    end

    def invoke(
      input_text : String,
      session_id : String,
      user_attrs : Hash(String, String),
      files : Array(InputFile),
    ) : AgentResponse
      session_id = Session.sanitize_id(session_id)
      attrs = Session.prompt_attributes.merge(user_attrs)

      body = build_request_body(input_text, attrs, files)
      uri = endpoint_uri(session_id)

      request = HTTP::Request.new("POST", uri.request_target, body: body)
      request.headers["Host"] = uri.host || "#{ENDPOINT_PREFIX}.#{@region}.amazonaws.com"
      request.headers["Content-Type"] = "application/json"
      @signer.sign(request)

      client = HTTP::Client.new(uri)
      client.connect_timeout = CONNECT_TIMEOUT
      client.read_timeout = READ_TIMEOUT

      response = client.exec(request)
      unless response.success?
        Log.error { "bedrock invoke failed: status=#{response.status_code}" }
        raise "bedrock agent invocation failed (#{response.status_code})"
      end

      parse_response(response)
    end

    private def endpoint_uri(session_id : String) : URI
      URI.parse(
        "https://#{ENDPOINT_PREFIX}.#{@region}.amazonaws.com" \
        "/agents/#{@agent_id}/agentAliases/#{@alias_id}" \
        "/sessions/#{session_id}/text"
      )
    end

    private def build_request_body(
      input_text : String,
      attrs : Hash(String, String),
      files : Array(InputFile),
    ) : String
      session_state = {
        "promptSessionAttributes" => JSON::Any.new(
          attrs.transform_values { |v| JSON::Any.new(v) }
        ),
      } of String => JSON::Any

      unless files.empty?
        session_state["files"] = JSON::Any.new(files.map { |file| build_input_file(file) })
      end

      {
        "inputText"    => JSON::Any.new(input_text),
        "enableTrace"  => JSON::Any.new(@enable_trace),
        "sessionState" => JSON::Any.new(session_state),
      }.to_json
    end

    private def build_input_file(file : InputFile) : JSON::Any
      JSON::Any.new({
        "name"    => JSON::Any.new(file.name),
        "useCase" => JSON::Any.new("CODE_INTERPRETER"),
        "source"  => JSON::Any.new({
          "sourceType"  => JSON::Any.new("BYTE_CONTENT"),
          "byteContent" => JSON::Any.new({
            "data"      => JSON::Any.new(Base64.strict_encode(file.data)),
            "mediaType" => JSON::Any.new(file.media_type),
          }),
        }),
      })
    end

    private def parse_response(response : HTTP::Client::Response) : AgentResponse
      io = IO::Memory.new(response.body)
      text = String::Builder.new
      sources = [] of String
      seen = Set(String).new
      output_files = [] of AgentFile

      knowledge_bases = Set(String).new
      action_groups = Set(String).new
      search_queries = [] of String
      rationale : String? = nil

      EventStream.decode(io) do |msg|
        if msg.exception?
          Log.error { "bedrock exception: #{String.new(msg.payload)}" }
          next
        end

        case msg.event_type
        when "chunk"
          parse_chunk(msg.payload, text, sources, seen)
        when "files"
          parse_files(msg.payload, output_files)
        when "trace"
          if r = TraceParser.parse(msg.payload, knowledge_bases, action_groups, search_queries, sources, seen)
            rationale = r
          end
        end
      end

      trace = TraceMetadata.new(
        knowledge_bases: knowledge_bases.to_a.sort,
        sources: sources,
        action_groups: action_groups.to_a.sort,
        search_queries: search_queries,
        rationale: rationale,
      )

      Log.info { "bedrock response: length=#{text.bytesize} sources=#{sources.size} output_files=#{output_files.size} kbs=#{knowledge_bases.size} action_groups=#{action_groups.size}" }
      AgentResponse.new(text: text.to_s, sources: sources, files: output_files, trace: trace)
    end

    private def parse_chunk(
      payload : Bytes,
      text : String::Builder,
      sources : Array(String),
      seen : Set(String),
    ) : Nil
      json = JSON.parse(String.new(payload))

      if bytes_b64 = json["bytes"]?.try(&.as_s?)
        text << String.new(Base64.decode(bytes_b64))
      end

      json["attribution"]?.try(&.["citations"]?).try(&.as_a).try &.each do |citation|
        citation["retrievedReferences"]?.try(&.as_a).try &.each do |ref|
          name = TraceParser.extract_source_name(ref) || next
          next if seen.includes?(name)
          seen << name
          sources << name
        end
      end
    end

    private def parse_files(payload : Bytes, output_files : Array(AgentFile)) : Nil
      json = JSON.parse(String.new(payload))
      json["files"]?.try(&.as_a).try &.each do |file|
        data_b64 = file["bytes"]?.try(&.as_s?) || next
        name = file["name"]?.try(&.as_s?) || "file"

        # Reject before decoding: base64 is ~4/3x raw size
        estimated_size = data_b64.bytesize * 3 // 4
        if estimated_size > Slack::MAX_OUTPUT_FILE_SIZE
          Log.warn { "skipping oversized agent file before decode: #{name} (~#{estimated_size} bytes)" }
          next
        end

        data = Base64.decode(data_b64)
        next if data.empty?

        output_files << AgentFile.new(
          name: name,
          media_type: file["type"]?.try(&.as_s?) || "application/octet-stream",
          data: data,
        )
      end
    end
  end
end

require "../../spec_helper"

private def build_trace_payload(
  rationale : String? = nil,
  kb_id : String? = nil,
  kb_query : String? = nil,
  action_group : String? = nil,
) : Bytes
  trace = {} of String => JSON::Any

  if rationale
    trace["preProcessingTrace"] = JSON::Any.new({
      "modelInvocationOutput" => JSON::Any.new({
        "parsedResponse" => JSON::Any.new({
          "rationale" => JSON::Any.new(rationale),
          "isValid"   => JSON::Any.new(true),
        } of String => JSON::Any),
      } of String => JSON::Any),
    } of String => JSON::Any)
  end

  invocation_input = {} of String => JSON::Any

  if kb_id
    kb_lookup = {"knowledgeBaseId" => JSON::Any.new(kb_id)} of String => JSON::Any
    kb_lookup["text"] = JSON::Any.new(kb_query.not_nil!) if kb_query
    invocation_input["knowledgeBaseLookupInput"] = JSON::Any.new(kb_lookup)
  end

  if action_group
    invocation_input["actionGroupInvocationInput"] = JSON::Any.new({
      "actionGroupName" => JSON::Any.new(action_group),
    } of String => JSON::Any)
  end

  unless invocation_input.empty?
    trace["orchestrationTrace"] = JSON::Any.new({
      "invocationInput" => JSON::Any.new(invocation_input),
    } of String => JSON::Any)
  end

  {"trace" => JSON::Any.new(trace)}.to_json.to_slice
end

describe Ark::Bedrock::TraceParser do
  it "extracts rationale from preprocessing trace" do
    payload = build_trace_payload(rationale: "User asks about leave policy")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    rationale = Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    rationale.should eq("User asks about leave policy")
  end

  it "extracts knowledge base ID" do
    payload = build_trace_payload(kb_id: "KB001", kb_query: "leave policy")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    kbs.should contain("KB001")
    queries.should eq(["leave policy"])
  end

  it "extracts action group name" do
    payload = build_trace_payload(action_group: "CodeInterpreter")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    ags.should contain("CodeInterpreter")
  end

  it "returns nil rationale when not present" do
    payload = build_trace_payload(kb_id: "KB001")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    rationale = Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    rationale.should be_nil
  end

  it "returns nil when trace key is missing" do
    payload = %({}).to_slice
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    rationale = Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    rationale.should be_nil
    kbs.should be_empty
    ags.should be_empty
  end

  it "ignores empty rationale" do
    payload = build_trace_payload(rationale: "")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    rationale = Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    rationale.should be_nil
  end

  it "ignores empty search query" do
    payload = build_trace_payload(kb_id: "KB001", kb_query: "")
    kbs = Set(String).new
    ags = Set(String).new
    queries = [] of String

    Ark::Bedrock::TraceParser.parse(payload, kbs, ags, queries)
    queries.should be_empty
  end
end

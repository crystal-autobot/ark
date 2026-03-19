require "../../spec_helper"

private def build_trace_payload(
  rationale : String? = nil,
  orch_rationale : String? = nil,
  kb_id : String? = nil,
  kb_query : String? = nil,
  action_group : String? = nil,
  kb_refs : Array(String)? = nil,
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

  orch_parts = {} of String => JSON::Any

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

  orch_parts["invocationInput"] = JSON::Any.new(invocation_input) unless invocation_input.empty?

  if orch_rationale
    orch_parts["rationale"] = JSON::Any.new({
      "text" => JSON::Any.new(orch_rationale),
    } of String => JSON::Any)
  end

  if kb_refs
    refs = kb_refs.map do |uri|
      JSON::Any.new({
        "location" => JSON::Any.new({
          "s3Location" => JSON::Any.new({
            "uri" => JSON::Any.new(uri),
          } of String => JSON::Any),
          "type" => JSON::Any.new("S3"),
        } of String => JSON::Any),
        "metadata" => JSON::Any.new({} of String => JSON::Any),
      } of String => JSON::Any)
    end
    orch_parts["observation"] = JSON::Any.new({
      "knowledgeBaseLookupOutput" => JSON::Any.new({
        "retrievedReferences" => JSON::Any.new(refs),
      } of String => JSON::Any),
    } of String => JSON::Any)
  end

  trace["orchestrationTrace"] = JSON::Any.new(orch_parts) unless orch_parts.empty?

  {"trace" => JSON::Any.new(trace)}.to_json.to_slice
end

private class ParseState
  getter kbs = Set(String).new
  getter ags = Set(String).new
  getter queries = [] of String
  getter sources = [] of String
  getter seen = Set(String).new
end

private def empty_parse_state
  ParseState.new
end

describe Ark::Bedrock::TraceParser do
  it "extracts rationale from preprocessing trace" do
    payload = build_trace_payload(rationale: "User asks about leave policy")
    state = empty_parse_state

    rationale = Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    rationale.should eq("User asks about leave policy")
  end

  it "extracts rationale from orchestration trace (Haiku)" do
    payload = build_trace_payload(orch_rationale: "I'll search the security KB")
    state = empty_parse_state

    rationale = Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    rationale.should eq("I'll search the security KB")
  end

  it "prefers preprocessing rationale over orchestration rationale" do
    payload = build_trace_payload(rationale: "preprocessing", orch_rationale: "orchestration")
    state = empty_parse_state

    rationale = Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    rationale.should eq("preprocessing")
  end

  it "extracts knowledge base ID" do
    payload = build_trace_payload(kb_id: "KB001", kb_query: "leave policy")
    state = empty_parse_state

    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.kbs.should contain("KB001")
    state.queries.should eq(["leave policy"])
  end

  it "extracts action group name" do
    payload = build_trace_payload(action_group: "CodeInterpreter")
    state = empty_parse_state

    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.ags.should contain("CodeInterpreter")
  end

  it "extracts sources from KB observation" do
    payload = build_trace_payload(kb_refs: [
      "s3://bucket/security-policies/password-policy.pdf",
      "s3://bucket/security-policies/access-control.pdf",
    ])
    state = empty_parse_state

    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.sources.should eq(["password-policy.pdf", "access-control.pdf"])
  end

  it "deduplicates sources via seen set" do
    payload = build_trace_payload(kb_refs: [
      "s3://bucket/doc.pdf",
      "s3://bucket/doc.pdf",
    ])
    state = empty_parse_state

    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.sources.should eq(["doc.pdf"])
  end

  it "skips sources already in seen set" do
    state = empty_parse_state
    state.seen << "doc.pdf"
    state.sources << "doc.pdf"

    payload = build_trace_payload(kb_refs: ["s3://bucket/doc.pdf"])
    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.sources.should eq(["doc.pdf"])
  end

  it "returns nil when trace key is missing" do
    payload = %({}).to_slice
    state = empty_parse_state

    rationale = Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    rationale.should be_nil
    state.kbs.should be_empty
    state.ags.should be_empty
  end

  it "ignores empty rationale" do
    payload = build_trace_payload(rationale: "")
    state = empty_parse_state

    rationale = Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    rationale.should be_nil
  end

  it "ignores empty search query" do
    payload = build_trace_payload(kb_id: "KB001", kb_query: "")
    state = empty_parse_state

    Ark::Bedrock::TraceParser.parse(payload, state.kbs, state.ags, state.queries, state.sources, state.seen)
    state.queries.should be_empty
  end
end

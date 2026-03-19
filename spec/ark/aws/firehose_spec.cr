require "../../spec_helper"

describe Ark::AWS::AnalyticsEvent do
  it "serializes to JSON with all fields" do
    trace = Ark::Bedrock::TraceMetadata.new(
      knowledge_bases: ["KB001"],
      sources: ["policy.pdf"],
      action_groups: ["CodeInterpreter"],
      search_queries: ["password policy"],
      rationale: "User is asking about policy",
    )
    event = Ark::AWS::AnalyticsEvent.new(
      user_id: "U123",
      thread_id: "1234-5678",
      message_length: 5,
      response_length: 42,
      trace: trace,
    )

    json = JSON.parse(event.to_json)
    json["user_id"].as_s.should eq("U123")
    json["thread_id"].as_s.should eq("1234-5678")
    json["message_length"].as_i.should eq(5)
    json["response_length"].as_i.should eq(42)
    json["knowledge_bases"].as_a.map(&.as_s).should eq(["KB001"])
    json["sources"].as_a.map(&.as_s).should eq(["policy.pdf"])
    json["action_groups"].as_a.map(&.as_s).should eq(["CodeInterpreter"])
    json["search_queries"].as_a.map(&.as_s).should eq(["password policy"])
    json["rationale"].as_s.should eq("User is asking about policy")
    json["timestamp"].as_s.should_not be_empty
  end

  it "serializes with nil rationale and empty arrays" do
    trace = Ark::Bedrock::TraceMetadata.new
    event = Ark::AWS::AnalyticsEvent.new(
      user_id: "U1",
      thread_id: "T1",
      message_length: 3,
      response_length: 4,
      trace: trace,
    )

    json = JSON.parse(event.to_json)
    json["rationale"]?.should be_nil
    json["knowledge_bases"].as_a.should be_empty
    json["sources"].as_a.should be_empty
    json["action_groups"].as_a.should be_empty
    json["search_queries"].as_a.should be_empty
  end

  it "generates RFC3339 timestamp" do
    trace = Ark::Bedrock::TraceMetadata.new
    event = Ark::AWS::AnalyticsEvent.new(
      user_id: "U1",
      thread_id: "T1",
      message_length: 3,
      response_length: 4,
      trace: trace,
    )
    Time.parse_rfc3339(event.timestamp)
  end
end

describe Ark::AWS::NullPublisher do
  it "accepts events without side effects" do
    trace = Ark::Bedrock::TraceMetadata.new
    publisher = Ark::AWS::NullPublisher.new
    event = Ark::AWS::AnalyticsEvent.new(
      user_id: "U1",
      thread_id: "T1",
      message_length: 3,
      response_length: 4,
      trace: trace,
    )
    publisher.publish(event)
  end
end

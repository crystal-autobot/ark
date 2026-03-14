require "../../spec_helper"

describe Ark::AWS::AnalyticsEvent do
  it "serializes to JSON with all fields" do
    event = Ark::AWS::AnalyticsEvent.new(
      user_id: "U123",
      thread_id: "1234-5678",
      user_message: "hello",
      response: "world",
    )

    json = JSON.parse(event.to_json)
    json["user_id"].as_s.should eq("U123")
    json["thread_id"].as_s.should eq("1234-5678")
    json["user_message"].as_s.should eq("hello")
    json["response"].as_s.should eq("world")
    json["timestamp"].as_s.should_not be_empty
  end

  it "generates RFC3339 timestamp" do
    event = Ark::AWS::AnalyticsEvent.new("U1", "T1", "msg", "resp")
    Time.parse_rfc3339(event.timestamp)
  end
end

describe Ark::AWS::NullPublisher do
  it "accepts events without side effects" do
    publisher = Ark::AWS::NullPublisher.new
    event = Ark::AWS::AnalyticsEvent.new("U1", "T1", "msg", "resp")
    publisher.publish(event)
  end
end

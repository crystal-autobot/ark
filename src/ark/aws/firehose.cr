require "json"
require "http/client"

module Ark::AWS
  struct AnalyticsEvent
    include JSON::Serializable

    getter timestamp : String
    getter user_id : String
    getter thread_id : String
    getter user_message : String
    getter response : String

    def initialize(@user_id : String, @thread_id : String, @user_message : String, @response : String)
      @timestamp = Time.utc.to_rfc3339
    end
  end

  abstract class EventPublisher
    abstract def publish(event : AnalyticsEvent) : Nil
  end

  class NullPublisher < EventPublisher
    def publish(event : AnalyticsEvent) : Nil
    end
  end

  class FirehosePublisher < EventPublisher
    PUBLISH_TIMEOUT = 5.seconds
    SERVICE         = "firehose"
    TARGET_PREFIX   = "Firehose_20150804"

    def initialize(@stream_name : String, @region : String, @provider : CredentialProvider)
      @signer = Signer.new(SERVICE, @region, @provider)
    end

    def publish(event : AnalyticsEvent) : Nil
      data = event.to_json + "\n"
      encoded = Base64.strict_encode(data)

      body = {
        "DeliveryStreamName" => @stream_name,
        "Record"             => {"Data" => encoded},
      }.to_json

      host = "#{SERVICE}.#{@region}.amazonaws.com"
      request = HTTP::Request.new("POST", "/", body: body)
      request.headers["Host"] = host
      request.headers["Content-Type"] = "application/x-amz-json-1.1"
      request.headers["X-Amz-Target"] = "#{TARGET_PREFIX}.PutRecord"

      @signer.sign(request)

      client = HTTP::Client.new(host, tls: true)
      client.connect_timeout = PUBLISH_TIMEOUT
      client.read_timeout = PUBLISH_TIMEOUT

      response = client.exec(request)
      unless response.success?
        Log.error { "firehose publish failed: status=#{response.status_code}" }
      end
    rescue ex
      Log.error(exception: ex) { "firehose publish error" }
    end
  end
end

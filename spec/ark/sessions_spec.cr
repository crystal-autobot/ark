require "../spec_helper"

describe Ark::Sessions do
  describe "#stale?" do
    it "is stale for unknown sessions" do
      Ark::Sessions.new(1.minute).stale?("s1").should be_true
    end

    it "is fresh after touch" do
      sessions = Ark::Sessions.new(1.minute)
      sessions.touch("s1")
      sessions.stale?("s1").should be_false
    end

    it "becomes stale after the ttl" do
      sessions = Ark::Sessions.new(0.seconds)
      sessions.touch("s1")
      sleep 1.millisecond
      sessions.stale?("s1").should be_true
    end
  end

  describe "#synchronize" do
    it "runs blocks for the same session one at a time" do
      sessions = Ark::Sessions.new(1.minute)
      order = [] of String
      done = Channel(Nil).new

      spawn do
        sessions.synchronize("s1") do
          order << "a-start"
          sleep 10.milliseconds
          order << "a-end"
        end
        done.send(nil)
      end
      spawn do
        sessions.synchronize("s1") do
          order << "b-start"
          order << "b-end"
        end
        done.send(nil)
      end

      2.times { done.receive }
      order.should eq(["a-start", "a-end", "b-start", "b-end"])
    end

    it "does not block different sessions" do
      sessions = Ark::Sessions.new(1.minute)
      order = [] of String
      done = Channel(Nil).new

      spawn do
        sessions.synchronize("s1") do
          order << "a-start"
          sleep 10.milliseconds
          order << "a-end"
        end
        done.send(nil)
      end
      spawn do
        sessions.synchronize("s2") { order << "b" }
        done.send(nil)
      end

      2.times { done.receive }
      order.should eq(["a-start", "b", "a-end"])
    end
  end
end

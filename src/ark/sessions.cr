module Ark
  class Sessions
    CLEANUP_THRESHOLD = 1000

    def initialize(@ttl : Time::Span)
      @last_used = {} of String => Time
      @locks = {} of String => Mutex
    end

    def synchronize(session_id : String, &) : Nil
      lock = @locks[session_id] ||= Mutex.new
      lock.synchronize { yield }
    end

    def stale?(session_id : String) : Bool
      last_used = @last_used[session_id]?
      return true unless last_used
      Time.utc - last_used > @ttl
    end

    def touch(session_id : String) : Nil
      @last_used[session_id] = Time.utc
      evict_stale if @last_used.size > CLEANUP_THRESHOLD
    end

    private def evict_stale : Nil
      cutoff = Time.utc - @ttl * 2
      @last_used.reject! { |_, last_used| last_used < cutoff }
      @locks.select! { |session_id, _| @last_used.has_key?(session_id) }
    end
  end
end

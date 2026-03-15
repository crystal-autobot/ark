module Ark::AWS
  abstract class CredentialProvider
    abstract def credentials : Credentials
  end

  class StaticCredentialProvider < CredentialProvider
    def initialize(@credentials : Credentials)
    end

    def credentials : Credentials
      @credentials
    end
  end

  class RefreshableCredentialProvider < CredentialProvider
    REFRESH_WINDOW = 10.minutes
    RETRY_COOLDOWN = 30.seconds

    def initialize(resolved : ResolvedCredentials, @resolver : -> ResolvedCredentials)
      @cached = resolved.credentials
      @expires_at = resolved.expires_at
      @retry_after = Time.utc
      @mutex = Mutex.new
    end

    def credentials : Credentials
      return @cached unless needs_refresh?

      @mutex.synchronize do
        return @cached unless needs_refresh?
        refresh
      end

      @cached
    end

    private def needs_refresh? : Bool
      expires_at = @expires_at
      return false unless expires_at
      Time.utc >= (expires_at - REFRESH_WINDOW) && Time.utc >= @retry_after
    end

    private def refresh : Nil
      resolved = @resolver.call
      @cached = resolved.credentials
      @expires_at = resolved.expires_at
      @retry_after = Time.utc
      Log.info { "refreshed AWS credentials, expires_at=#{@expires_at}" }
    rescue ex
      @retry_after = Time.utc + RETRY_COOLDOWN
      Log.error(exception: ex) { "failed to refresh AWS credentials, using cached (expires_at=#{@expires_at}, retry_after=#{@retry_after})" }
    end
  end
end

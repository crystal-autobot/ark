require "awscr-signer"

module Ark::AWS
  class Signer
    def initialize(service : String, region : String, credentials : Credentials)
      @signer = Awscr::Signer::Signers::V4.new(
        service,
        region,
        credentials.access_key_id,
        credentials.secret_access_key,
        credentials.session_token,
      )
    end

    def sign(request : HTTP::Request) : Nil
      @signer.sign(request)
    end
  end
end

require "awscr-signer"

module Ark::AWS
  class Signer
    def initialize(@service : String, @region : String, @provider : CredentialProvider)
    end

    def sign(request : HTTP::Request) : Nil
      creds = @provider.credentials
      signer = Awscr::Signer::Signers::V4.new(
        @service,
        @region,
        creds.access_key_id,
        creds.secret_access_key,
        creds.session_token,
      )
      signer.sign(request)
    end
  end
end

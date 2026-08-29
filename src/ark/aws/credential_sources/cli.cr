module Ark::AWS::CredentialSources::Cli
  EXECUTABLE = "aws"

  def self.available? : Bool
    !Process.find_executable(EXECUTABLE).nil?
  end

  def self.resolve(profile : String? = nil) : ResolvedCredentials
    args = ["configure", "export-credentials"]
    args += ["--profile", profile] if profile

    output = IO::Memory.new
    error = IO::Memory.new

    begin
      status = Process.run(EXECUTABLE, args, output: output, error: error)
    rescue File::NotFoundError
      raise "AWS CLI not found. Install it or provide AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY"
    end

    unless status.success?
      label = profile ? "profile [#{profile}]" : "default chain"
      raise "failed to export AWS credentials (#{label}): #{error.to_s.strip}"
    end

    Credentials.from_json(output.to_s, "AWS CLI")
  end
end

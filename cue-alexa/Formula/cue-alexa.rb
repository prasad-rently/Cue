# Homebrew formula for cue-alexa (CUE-A-23 / FR-050).
# Test locally: brew install --build-from-source ./Formula/cue-alexa.rb
class CueAlexa < Formula
  desc "Amazon Alexa engine for Cue — send text commands to Echo devices from the terminal"
  homepage "https://github.com/gokul/cue-alexa"
  url "https://github.com/gokul/cue-alexa/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "..."  # filled in at release time
  license "MIT"
  version "0.1.0"

  depends_on "bash"
  depends_on "jq"
  depends_on "oath-toolkit" # oathtool, for credential+TOTP login

  def install
    libexec.install "bin", "lib", "vendor", "VERSION"
    (bin/"cue-alexa").write <<~SH
      #!/usr/bin/env bash
      exec "#{libexec}/bin/cue-alexa" "$@"
    SH
    chmod 0755, bin/"cue-alexa"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cue-alexa --version")
    assert_match "\"name\": \"alexa\"", shell_output("#{bin}/cue-alexa --cue-engine-info")
  end
end

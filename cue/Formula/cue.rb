# Homebrew formula for the cue umbrella router (P4).
# Test locally: brew install --build-from-source ./Formula/cue.rb
class Cue < Formula
  desc "Umbrella router for Cue — route text commands to voice-assistant engines"
  homepage "https://github.com/prasad-rently/Cue"
  url "https://github.com/prasad-rently/Cue/archive/refs/tags/cue-v0.1.0.tar.gz"
  # sha256 "..."  # filled in at release time
  license "MIT"
  version "0.1.0"

  depends_on "bash"
  depends_on "jq"
  # Engines are optional and discovered on PATH:
  #   brew install prasad-rently/tap/cue-alexa
  #   brew install prasad-rently/tap/cue-google

  def install
    libexec.install "bin", "lib", "VERSION"
    (bin/"cue").write <<~SH
      #!/usr/bin/env bash
      exec "#{libexec}/bin/cue" "$@"
    SH
    chmod 0755, bin/"cue"
    bash_completion.install "share/completions/cue.bash" => "cue"
    zsh_completion.install  "share/completions/_cue"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cue --version")
    assert_match "No engines", shell_output("#{bin}/cue engines")
  end
end

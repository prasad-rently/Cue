# Homebrew formula for cue-google (CUE-G-23 / FR-060).
class CueGoogle < Formula
  desc "Google Assistant engine for Cue — send text commands to Home/Nest from the terminal"
  homepage "https://github.com/prasad-rently/Cue"
  url "https://github.com/prasad-rently/Cue/archive/refs/tags/cue-google-v0.1.0.tar.gz"
  # sha256 "..."  # filled in at release time
  license "MIT"
  version "0.1.0"

  depends_on "bash"
  depends_on "jq"
  depends_on "python@3.12"

  def install
    libexec.install "bin", "lib", "pysrc", "requirements.lock", "VERSION"
    (bin/"cue-google").write <<~SH
      #!/usr/bin/env bash
      exec "#{libexec}/bin/cue-google" "$@"
    SH
    chmod 0755, bin/"cue-google"
    bash_completion.install "share/completions/cue-google.bash" => "cue-google"
    zsh_completion.install  "share/completions/_cue-google"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cue-google --version")
    assert_match "\"name\": \"google\"", shell_output("#{bin}/cue-google --cue-engine-info")
  end
end

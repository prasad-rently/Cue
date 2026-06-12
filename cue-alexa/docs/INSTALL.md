# Installing cue-alexa

## Requirements
- `bash` 4+ (macOS ships 3.2 → `brew install bash`)
- `jq`
- `oath-toolkit` (`oathtool`) — only for credential+TOTP login

## macOS (Homebrew)
```bash
brew install --build-from-source ./Formula/cue-alexa.rb   # local
# or, once tapped: brew install gokul/tap/cue-alexa
```

## Linux / from source (no sudo)
```bash
git clone https://github.com/gokul/cue-alexa && cd cue-alexa
./install.sh                       # installs to /usr/local or ~/.local
export PATH="$HOME/.local/bin:$PATH"   # if it fell back to ~/.local
```

## Verify
```bash
cue-alexa --version
cue-alexa login
cue-alexa doctor
```
See [COMMANDS.md](COMMANDS.md) for usage and [../VALIDATION.md](../VALIDATION.md) to validate offline.

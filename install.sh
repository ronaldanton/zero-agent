#!/usr/bin/env bash
# ZeroAgent installer: Hermes core + the zero overlay (profile, skill pack, cron self-learning).
set -euo pipefail

ZEROREPO="${ZEROREPO:-https://github.com/ronaldanton/zero-agent}"
ZERODIR="$HOME/.zero-agent"
export PATH="$HOME/.local/bin:$PATH"
PROFILE="zero"

TS_MODE=false
[ "${1:-}" = "--tailscale" ] && TS_MODE=true

if $TS_MODE; then
  echo "[zero] --tailscale: installing Tailscale, OpenCode, Token Harbor config..."
  if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if [ -n "${TAILSCALE_AUTH_KEY:-}" ]; then
    tailscale up --authkey "$TAILSCALE_AUTH_KEY" --hostname "$(hostname)-zero" || true
  else
    echo "[zero] run 'sudo tailscale up --hostname $(hostname)-zero' once to join the tailnet"
  fi
  if ! command -v opencode >/dev/null 2>&1; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
  fi
  if [ -n "${TOKENHARBOR_API_KEY:-}" ]; then
    mkdir -p "$HOME/.local/share/opencode"
    echo "{\"tokenharbor\":{\"type\":\"api\",\"key\":\"$TOKENHARBOR_API_KEY\"}}"
      > "$HOME/.local/share/opencode/auth.json"
    mkdir -p "$HOME/.config/opencode"
    cat > "$HOME/.config/opencode/opencode.json" <<'OC'
{
  "provider": {
    "tokenharbor": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Token Harbor",
      "options": {"baseURL": "https://tokenharbor.ai/v1"}
    }
  }
}
OC
    echo "[zero] Token Harbor provider configured for opencode"
  else
    echo "[zero] set TOKENHARBOR_API_KEY to preconfigure opencode; without it run: opencode auth login"
  fi
fi

echo "[zero] 1/3 Installing Hermes Agent core..."
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

echo "[zero] 2/3 Cloning ZeroAgent overlay..."
if ! git clone --depth 1 "$ZEROREPO" "$ZERODIR" 2>/dev/null; then
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/ronaldanton/zero-agent" "$ZERODIR"
  else
    git -C "$ZERODIR" pull --ff-only 2>/dev/null || { echo "[zero] private repo needs GITHUB_TOKEN set"; exit 1; }
  fi
fi

echo "[zero] 3/3 Installing zero profile + skill pack..."
if hermes profile list >/dev/null 2>&1 && ! hermes profile list | grep -q "$PROFILE"; then
  hermes profile create "$PROFILE"
fi
# skill pack: symlink so it stays update-tracked
for d in "$ZERODIR"/skills/*/; do
  name=$(basename "$d")
  mkdir -p "$HOME/.hermes/profiles/$PROFILE/skills/"
  ln -sfn "$d" "$HOME/.hermes/profiles/$PROFILE/skills/$name"
done

# hourly self-learning cron (skill review -> update skills)
if hermes -p "$PROFILE" cron list --all 2>/dev/null | grep -q zero-learn; then
  echo "[zero] self-learning cron already present"
else
  hermes -p "$PROFILE" cron create 60m \
    "Review the most recent sessions for this profile. Extract at most ONE durable lesson (reusable procedure, pitfall, or correction) and persist it into the matching skill with skill_manage. If nothing durable: exit without doing anything." \
    --name zero-learn --deliver local >/dev/null 2>&1 || \
    echo "[zero] add the self-learning cron later: hermes -p $PROFILE cron create 60m '...' --name zero-learn --deliver local"
fi

echo "[zero] Done. Start with:  hermes -p $PROFILE  (or: hermes -p $PROFILE chat -q 'hello')"
hermes -p "$PROFILE" doctor || true

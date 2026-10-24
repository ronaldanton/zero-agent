#!/usr/bin/env bash
# ZeroAgent installer: Hermes core + the zero overlay (profile, skill pack, cron self-learning).
set -euo pipefail

ZEROREPO="${ZEROREPO:-https://github.com/ronaldanton/zero-agent}"
ZERODIR="$HOME/.zero-agent"
PROFILE="zero"

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
if hermes cron list --all 2>/dev/null | grep -q zero-learn; then
  echo "[zero] self-learning cron already present"
else
  hermes cron create 'hourly' \
    --prompt "Review the most recent completed sessions for this profile. Extract one durable lesson (procedure, pitfall, correction) that applies to recurring task types, and persist it with skill_manage under the matching skill. If nothing durable, do nothing. Keep it short." \
    --name zero-learn --profile "$PROFILE" --deliver-to local >/dev/null 2>&1 || \
    echo "[zero] add the self-learning cron later: hermes cron create 'hourly' ..."
fi

echo "[zero] Done. Start with:  hermes -p $PROFILE  (or: hermes -p $PROFILE chat -q 'hello')"
hermes -p "$PROFILE" doctor || true

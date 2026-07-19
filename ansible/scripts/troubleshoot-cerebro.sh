#!/usr/bin/env bash
# Diagnostic for the mqz-cerebro deploy flow.
# Emulates every touchpoint the role uses (docker CLI, sudo, host dirs,
# existing containers, compose file, python venv) and dumps state.
# Read-only — makes no changes on cerebro.
#
# Invoked via: just ansible troubleshoot

set -euo pipefail

TARGET_HOST="${CEREBRO_HOST:-192.168.1.250}"
TARGET_USER="${CEREBRO_USER:-krakoa}"
OUTPUT="${OUTPUT:-/tmp/cerebro-troubleshoot.log}"

echo "🔍 Cerebro deploy-flow troubleshoot"
echo "   host:   $TARGET_USER@$TARGET_HOST"
echo "   output: $OUTPUT"
echo

# Fail fast if key auth isn't working
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "❌ Cannot SSH to $TARGET_USER@$TARGET_HOST (key auth failed)."
  echo "   Verify with: ssh -o BatchMode=yes $TARGET_USER@$TARGET_HOST 'echo ok'"
  exit 1
fi

ssh -o BatchMode=yes "$TARGET_USER@$TARGET_HOST" 'bash -s' <<'REMOTE' 2>&1 | tee "$OUTPUT"
set +e

# DSM's Container Manager installs docker at /usr/local/bin/docker, which
# is NOT in the PATH of a non-login shell (which is what `bash -s` gives us).
# Use the full path throughout instead of relying on discovery.
DOCKER=/usr/local/bin/docker

echo "===== 0. RUN CONTEXT ====="
echo "date:     $(date -Iseconds)"
echo "hostname: $(hostname)"
echo "id:       $(id)"
grep -E '^(productversion|buildnumber|smallfixnumber)=' /etc/synoinfo.conf 2>/dev/null | head -5

echo
echo "===== 1. TOOL AVAILABILITY (as ansible_user) ====="
"$DOCKER" --version 2>&1
"$DOCKER" compose version 2>&1
ls -la /var/run/docker.sock

echo
echo "===== 2. AS ROOT (what ansible sees under become) ====="
sudo -n bash -c "echo PATH=\$PATH; $DOCKER --version 2>&1; $DOCKER compose version 2>&1"

echo
echo "===== 3. HOME DIR RESOLUTION ====="
echo "\$HOME: $HOME"
readlink -f "$HOME" 2>/dev/null
ls -ld "/home/$(whoami)" 2>&1
ls -ld "/var/services/homes/$(whoami)" 2>&1
ls -ld "/volume1/homes/$(whoami)" 2>&1

echo
echo "===== 4. CURRENT CONTAINERS ====="
sudo -n "$DOCKER" ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>&1

echo
echo "===== 5. COMPOSE-PROJECT LABEL PER EXISTING CONTAINER ====="
for name in portainer calibre-web-automated iptvboss eplustv pluto-for-channels olivetin static-file-server acme.sh syncthing nzbget deluge sonarr radarr channels-remote adbtuner; do
  if sudo -n "$DOCKER" inspect "$name" >/dev/null 2>&1; then
    label=$(sudo -n "$DOCKER" inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>&1)
    if [ -n "$label" ] && [ "$label" != "<no value>" ]; then
      printf '%-30s label = %s\n' "$name" "$label"
    else
      printf '%-30s NO compose project label (manual container)\n' "$name"
    fi
  else
    printf '%-30s does not exist\n' "$name"
  fi
done

echo
echo "===== 6. HOST DIR OWNERSHIP UNDER /volume1/docker/ ====="
for dir in portainer calibre calibre/config calibre/library calibre/ingest eplustv iptv-boss syncthing syncthing/config syncthing/data olivetin olivetin/config acme-sh nzbget deluge sonarr radarr; do
  ls -ld "/volume1/docker/$dir" 2>&1
done

echo
echo "===== 6b. KNOWN OWNER-USER UIDS ====="
for user in krakoa boogey the-collector; do
  id "$user" 2>&1
done

echo
echo "===== 7. EXISTING MERGED COMPOSE FILE ====="
for path in ~/compose.yaml /home/krakoa/compose.yaml; do
  ls -la "$path" 2>&1
  if [ -f "$path" ]; then
    echo "--- first 30 lines of $path ---"
    head -30 "$path"
  fi
done

echo
echo "===== 8. SUDOERS CONFIG FOR ansible_user ====="
sudo -n cat "/etc/sudoers.d/$(whoami)" 2>&1

echo
echo "===== 9. ANSIBLE PYTHON INTERPRETER ====="
ANSIBLE_PY="/volume1/homes/$(whoami)/.venvs/ansible/bin/python"
ls -la "$ANSIBLE_PY" 2>&1
"$ANSIBLE_PY" --version 2>&1
"$ANSIBLE_PY" -c 'import docker; print("docker SDK", docker.__version__)' 2>&1

echo
echo "===== END OF DIAGNOSTIC ====="
REMOTE

echo
echo "✅ Full output saved to: $OUTPUT"
echo "   (paste the contents in chat so the whole state is visible at once)"

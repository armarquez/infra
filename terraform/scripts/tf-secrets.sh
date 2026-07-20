#!/usr/bin/env bash
# Decrypts ansible-vault, extracts named keys, and prints
#   export TF_VAR_<name>=<quoted-value>
# lines on stdout for the caller to `eval`. Never writes secrets to disk.
#
# Consumed by terraform/justfile (`_with-secrets` recipe) so `just terraform
# apply` can source secrets from Ansible Vault without a second copy anywhere.
#
# Requires:
#   - PROJECT_ROOT env var (exported by root .envrc via direnv)
#   - Ansible venv installed (`just ansible install`)
#   - 1Password CLI unlocked (`~/bin/op-vault` handles this)
#   - yq v4 on PATH (mise-managed)
set -euo pipefail

: "${PROJECT_ROOT:?PROJECT_ROOT must be set — did direnv load ../.envrc?}"

VAULT="$PROJECT_ROOT/ansible/group_vars/secrets.yaml"
ANSIBLE_VAULT="$PROJECT_ROOT/ansible/.venv/bin/ansible-vault"
VAULT_PASSWORD_FILE="${HOME}/bin/op-vault"

if [[ ! -x "$ANSIBLE_VAULT" ]]; then
  echo "# ERROR: $ANSIBLE_VAULT not found — run 'just ansible install' first" >&2
  exit 1
fi

if [[ ! -x "$VAULT_PASSWORD_FILE" ]]; then
  echo "# ERROR: $VAULT_PASSWORD_FILE not found — run 'just ansible install-op-vault' first" >&2
  exit 1
fi

# Pass --vault-password-file explicitly so the script works regardless of
# cwd. ansible.cfg's vault_password_file setting only applies when cwd is
# the ansible/ dir (as when invoked via `just ansible ...`).
VAULT_YAML=$("$ANSIBLE_VAULT" view --vault-password-file="$VAULT_PASSWORD_FILE" "$VAULT")

emit() {
  local tf_var=$1 vault_key=$2
  local val
  val=$(printf '%s\n' "$VAULT_YAML" | yq -r ".${vault_key} // \"\"")
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "# WARN: vault key '${vault_key}' is empty or missing — skipping TF_VAR_${tf_var}" >&2
    return
  fi
  printf 'export TF_VAR_%s=%q\n' "$tf_var" "$val"
}

# Currently in use by terraform/environments/home:
emit cloudflare_api_token cloudflare_caddy_api_token
emit cloudflare_zone_id   cloudflare_zone_id

# Not yet in use — uncomment as terraform starts to manage the corresponding
# resources. Each vault key on the right must exist in secrets.yaml.
# emit proxmox_api_token             proxmox_terraform_api_token
# emit tailscale_oauth_client_id     tailscale_oauth_client_id
# emit tailscale_oauth_client_secret tailscale_oauth_client_secret

#!/usr/bin/env bash
# Prepare the local Vault for the project. Safe to run again:
#   - first run:            init, unseal, KV v2 engine `secret/`, policy `aws-testtask`, project token
#   - after a Vault restart: unseal (Vault always starts sealed) and renew the project token
# Uses the `vault` CLI if it is installed, otherwise the CLI inside the container of vault/docker-compose.yml.
#   vault/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")"

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
INIT_FILE=.vault-init.json   # unseal key + root token. In .gitignore — keep a copy outside this machine
TOKEN_FILE=.vault-token      # token for Terraform and Ansible (policy aws-testtask)

vault() {
    if command -v vault >/dev/null; then
        command vault "$@"
    else
        docker compose exec -T -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="${VAULT_TOKEN:-}" vault vault "$@"
    fi
}

json_field() { python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1"; }
# exit code 2 (sealed) is a normal state here
status_field() { { vault status -format=json || true; } | json_field "$1"; }

# `vault status` exit codes: 0 — unsealed, 2 — sealed, 1 — not reachable
echo "Waiting for Vault at $VAULT_ADDR ..."
for _ in $(seq 30); do
    rc=0; vault status >/dev/null 2>&1 || rc=$?
    [ "$rc" -ne 1 ] && break
    sleep 1
done
[ "$rc" -eq 1 ] && { echo "Vault is not reachable. Start it: docker compose -f vault/docker-compose.yml up -d" >&2; exit 1; }

if [ "$(status_field initialized)" = False ]; then
    echo "Initialising Vault (1 unseal key) -> vault/$INIT_FILE"
    (umask 077; vault operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_FILE")
fi
[ -f "$INIT_FILE" ] || { echo "Vault is initialised, but vault/$INIT_FILE is missing" >&2; exit 1; }

if [ "$(status_field sealed)" = True ]; then
    echo "Unsealing"
    vault operator unseal "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["unseal_keys_b64"][0])' "$INIT_FILE")" >/dev/null
fi

VAULT_TOKEN="$(json_field root_token < "$INIT_FILE")"
export VAULT_TOKEN

if ! vault secrets list -format=json | grep -q '"secret/"'; then
    echo "Enabling the KV v2 engine at secret/"
    vault secrets enable -path=secret -version=2 kv >/dev/null
fi

vault policy write aws-testtask - < policies/aws-testtask.hcl >/dev/null

# Periodic token: never expires while it is renewed at least once in 32 days (every run of this script renews it)
if [ -s "$TOKEN_FILE" ] && VAULT_TOKEN="$(cat "$TOKEN_FILE")" vault token renew >/dev/null 2>&1; then
    echo "Project token renewed"
else
    echo "Creating the project token -> vault/$TOKEN_FILE"
    (umask 077; vault token create -policy=aws-testtask -period=768h -display-name=aws-testtask -field=token > "$TOKEN_FILE")
fi

cat <<EOF

Vault is ready. In every shell that runs Terraform or Ansible:
  export VAULT_ADDR=$VAULT_ADDR
  export VAULT_TOKEN=\$(cat "$(pwd)/$TOKEN_FILE")
EOF

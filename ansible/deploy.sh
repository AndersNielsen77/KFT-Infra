#!/usr/bin/env bash
# Convenience wrapper referenced by the README's Quick Start.
# Usage: ./deploy.sh prod|test [-- extra ansible-playbook args]

set -euo pipefail

ENV="${1:-}"
shift || true

if [[ "$ENV" != "prod" && "$ENV" != "test" ]]; then
  echo "Usage: $0 prod|test [-- extra ansible-playbook args]"
  exit 1
fi

INVENTORY="inventory/$ENV/hosts.yml"

if [[ ! -f "$INVENTORY" ]]; then
  echo "Missing $INVENTORY - copy inventory/hosts.yml.example there and fill in your values first."
  exit 1
fi

if [[ "$ENV" == "test" ]]; then
  echo "==> Bootstrapping SSH access for the test environment"
  ansible-playbook -i "$INVENTORY" playbooks/bootstrap.yml
fi

echo "==> Applying site.yml (home-lab services) against $ENV"
ansible-playbook -i "$INVENTORY" playbooks/site.yml "$@"

echo ""
echo "Note: Zabbix (central server + customer proxies) is a separate playbook,"
echo "not part of site.yml - run it explicitly when needed:"
echo "  ansible-playbook -i $INVENTORY playbooks/zabbix.yml"

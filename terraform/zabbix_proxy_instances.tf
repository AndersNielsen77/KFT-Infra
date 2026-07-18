# =============================================================================
# Zabbix Proxy Instances - one per customer
# =============================================================================
# The "local-test" instance below is the reference/test deployment, running
# on this home-lab node. It exists to validate the whole pattern (proxy +
# WireGuard tunnel + registration with the central server) before the same
# pattern gets used on a real customer's Proxmox node - it is not itself a
# customer, it's the staging ground for onboarding real ones.
#
# This matches the CT built by hand on 2026-07-18 (vm_id 116, DHCP on
# vmbr0). To bring the existing container under Terraform:
#   terraform import module.zabbix_proxy_local_test.proxmox_virtual_environment_container.proxy pve/116
#
# --- Onboarding a new customer ---
# 1. Add a module block below (their own node_name/provider if they run their
#    own Proxmox host - see ovh_provider.tf for the pattern of adding a new
#    provider alias per remote node).
# 2. Pick an unused vm_id on their node, and an unused WireGuard tunnel
#    subnet (see docs/zabbix-monitoring.md for the octet ledger).
# 3. terraform apply -target=module.zabbix_proxy_<customer>
# 4. ansible-playbook playbooks/zabbix.yml --limit zabbix_proxy_<customer>
# 5. Registration on the central server happens automatically as part of
#    that playbook run (see roles/zabbix_server/tasks/register_proxy.yml).

module "zabbix_proxy_local_test" {
  source = "./modules/zabbix_proxy"

  customer_name           = "local-test"
  node_name               = var.node_name # this repo's home-lab node
  vm_id                   = 116
  storage                 = "local-lvm"
  bridge                  = var.bridge_main
  ip_address              = "dhcp"
  ansible_ssh_public_keys = var.ansible_ssh_public_keys
}

# Example for a real customer running their own Proxmox node - uncomment,
# fill in, and add a matching provider alias if it's a different node:
#
# module "zabbix_proxy_acme_corp" {
#   source = "./modules/zabbix_proxy"
#
#   customer_name = "acme-corp"
#   node_name     = "acme-pve"
#   vm_id         = 200
#   bridge        = "vmbr0"
#   ip_address    = "dhcp"
# }

output "zabbix_proxy_local_test_id" {
  value = module.zabbix_proxy_local_test.vm_id
}

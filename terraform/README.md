# Terraform Infrastructure

This directory contains Terraform configurations for managing Proxmox infrastructure.

## Directory Structure

```
terraform/
├── containers.tf      # LXC container definitions
├── vms.tf            # VM definitions
├── provider.tf       # Proxmox provider configuration
├── variables.tf      # Variable definitions
├── versions.tf       # Terraform and provider version constraints
├── outputs.tf        # Output definitions
├── dev.tfvars        # Development environment variables
├── prod.tfvars       # Production environment variables
└── _old_root_config/ # Backup of previous configs
```

## Usage

The same Terraform code is used for both dev and prod environments. You control which environment by using different `.tfvars` files.

### Development Environment

```bash
cd terraform
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Production Environment

```bash
cd terraform
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Key Differences

**Dev Environment (`dev.tfvars`):**
- Single network bridge (vmbr0) for simplicity
- Simplified networking configuration
- Perfect for testing changes before applying to production

**Prod Environment (`prod.tfvars`):**
- Dual network bridges (vmbr0 + vmbr1) with VLANs
- Fixed MAC addresses for network consistency
- Full production configuration with proper network segmentation

## Best Practice Workflow

1. Test changes in dev first:
   ```bash
   terraform apply -var-file=dev.tfvars
   ```

2. Verify everything works correctly

3. Apply the same code to production:
   ```bash
   terraform apply -var-file=prod.tfvars
   ```

This ensures you're testing the **exact same code** that will run in production, just with different network settings.

## Notes

- Both environments share the same Terraform state by default
- Consider using Terraform workspaces or remote state if you need separate state files
- The `*.tfvars` files contain sensitive credentials and should be gitignored

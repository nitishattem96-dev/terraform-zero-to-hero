# Terraform Import: Modern Method (`import` block)

Quick revision notes for importing an existing AWS resource (example: EC2 instance) into Terraform.

## When to use

You have a resource that was created manually (console/CLI) and you want Terraform to manage it **without recreating it**.

## Folder layout

```
tf-import-lab/
├── provider.tf      # terraform + provider blocks
├── import.tf        # the import block (temporary)
└── generated.tf     # generated resource block (cleaned by hand)
```

Terraform reads every `.tf` file in the folder, so filenames don't matter. Never keep the same resource in two files (`Duplicate resource` error).

## Steps

### 1. Provider setup (`provider.tf`)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}
```

### 2. Add the import block (`import.tf`)

```hcl
import {
  to = aws_instance.legacy        # address in Terraform
  id = "i-0abc123456789"          # real instance ID in AWS
}
```

### 3. Initialize and generate config

```bash
terraform init
terraform plan -generate-config-out=generated.tf
```

- `init` downloads the AWS provider.
- `-generate-config-out` reads the real resource and writes a `resource` block into `generated.tf`.
- **Nothing is imported at this step.** It fails if `generated.tf` already exists (delete it first to regenerate).

### 4. Clean `generated.tf`

Generated config includes read-only values and conflicts. Fix them by hand.

**Delete computed-only attributes:**

```
arn, id, instance_state, instance_lifecycle, outpost_arn, password_data,
primary_network_interface_id, private_dns, public_dns, public_ip,
spot_instance_request_id, tags_all
```

Inside `root_block_device`, delete `device_name` and `volume_id`.

**Resolve conflicting pairs:**

| Conflict | Fix |
|---|---|
| `ipv6_address_count` vs `ipv6_addresses` | Delete both (if unused) |
| `placement_group` vs `placement_group_id` | Delete both (if empty) |
| `primary_network_interface` vs `associate_public_ip_address` | Delete the `primary_network_interface` block |
| `security_groups` vs `vpc_security_group_ids` | Keep only `vpc_security_group_ids` (IDs) |

**Delete empty values:** any `= ""` or `= null` lines (e.g. `amd_sev_snp = ""`, `nested_virtualization = ""`).

Then loop until clean:

```bash
terraform fmt
terraform validate
```

### 5. Plan and check the summary line

```bash
terraform plan
```

| Summary | Meaning | Action |
|---|---|---|
| `1 to import, 0 to add` | Correct | Continue |
| `1 to add` | Import not picked up, would create a NEW resource | **Stop**, check `import.tf` |
| `1 to import, 1 to change` | Config differs from reality | Edit config to match the real values |
| Any `destroy` / `replace` | Dangerous | **Stop**, fix config |

### 6. Apply (this performs the import)

```bash
terraform apply
```

Type `yes`. The import happens here, not in step 3.

### 7. Verify

```bash
terraform plan          # must say: No changes
terraform state list    # should list aws_instance.legacy
```

### 8. Finish

```bash
rm import.tf            # no longer needed
mv generated.tf main.tf # optional tidy-up
terraform plan          # still "No changes"
```

## Command reference

| Command | What it does | Safe? |
|---|---|---|
| `terraform init` | Downloads providers, sets up the folder | Yes |
| `terraform fmt` | Formats files (whitespace only) | Yes |
| `terraform validate` | Checks syntax and schema, no AWS calls | Yes |
| `terraform plan` | Shows what would change | Yes |
| `terraform plan -generate-config-out=FILE` | Plan and write config for import blocks | Yes |
| `terraform apply` | Executes the plan (performs the import) | Changes state / infra |
| `terraform state list` | Lists tracked resources | Yes |
| `terraform state show ADDR` | Shows recorded attributes of a resource | Yes |
| `terraform state rm ADDR` | Forgets a resource, does NOT delete it in AWS | Changes state only |
| `terraform destroy` | Deletes everything Terraform manages | Destructive |

## Errors I hit and what they meant

| Error | Cause | Fix |
|---|---|---|
| `Value for unconfigurable attribute` | Read-only attribute in generated config | Delete that line |
| `Conflicting configuration arguments` | Two mutually exclusive attributes set | Keep one or delete both |
| `expected X to be one of [...], got ""` | Empty string placeholder | Delete the line |
| `Argument is computed` (warning, `tags_all`) | Provider-managed attribute | Delete `tags_all`, keep `tags` |
| `Plan: 1 to add` for an existing resource | Resource not in state | Use the import block and apply |
| `InvalidGroup.NotFound: security group 'launch-wizard-1'` | Config used `security_groups` (name) for a group that doesn't exist | Use `vpc_security_group_ids` with a real `sg-` ID |

## Golden rules

1. After import, `terraform plan` must say **"No changes"**.
2. Never apply a plan showing `add`, `destroy` or `replace` for something you meant to import.
3. Import blocks need `apply` to take effect.
4. Generate into a new file, never one that already has your code.
5. Use either the `import` block **or** `terraform import`, not both.
6. Run `terraform destroy` after lab practice to avoid charges.
# Terraform Drift Detection

Quick revision notes for detecting and resolving configuration drift.

## What is drift?

**Drift** is when real infrastructure no longer matches what Terraform's config and state describe, usually because someone changed something manually in the AWS console or CLI.

Terraform compares three things:

| Source | What it is |
|---|---|
| **Config** (`.tf` files) | The desired state |
| **State** (`terraform.tfstate`) | What Terraform last recorded |
| **Real infrastructure** (AWS) | What actually exists |

Drift = real infrastructure differs from state/config.

## Commands at a glance

| Goal | Command | Changes anything? |
|---|---|---|
| Detect drift only | `terraform plan -refresh-only` | No |
| See what Terraform would change | `terraform plan` | No |
| **Revert AWS to match your code** | `terraform apply` | Yes (AWS) |
| Record manual changes in state | `terraform apply -refresh-only` | Yes (state only) |
| Detect drift in scripts/CI | `terraform plan -refresh-only -detailed-exitcode` | No |

Note: a normal `terraform plan` also reports drift (in the "Objects have changed outside of Terraform" section), but `-refresh-only` shows drift without pending code changes mixed in.

## Lab: create, detect and resolve drift

### 1. Baseline

```bash
terraform plan
```

Must say **"No changes."** before starting.

### 2. Create drift manually

AWS Console, EC2, select the instance, **Tags, Manage tags**:

- Change `Name` to `changed-in-console`
- Add tag `Owner = someone-else`
- Save

### 3. Detect it

```bash
terraform plan -refresh-only
```

Expected output:

```
Note: Objects have changed outside of Terraform
  # aws_instance.legacy has changed
  ~ tags = {
      ~ "Name"  = "legacy-server" -> "changed-in-console"
      + "Owner" = "someone-else"
    }
```

### 4. Resolve it (pick one)

#### Option A: Revert the console change (code is the source of truth)

```bash
terraform plan      # preview the revert
terraform apply     # type yes
terraform plan      # No changes
```

Safer for real work, apply exactly what you reviewed:

```bash
terraform plan -out=revert.tfplan
terraform apply revert.tfplan
```

#### Option B: Accept the console change (console is the new truth)

1. Edit the config to match reality:

```hcl
tags = {
  Name  = "changed-in-console"
  Owner = "someone-else"
}
```

2. Sync state (no AWS changes):

```bash
terraform apply -refresh-only
```

3. Verify:

```bash
terraform plan      # No changes
```

> Both steps are required. Updating only state leaves the config out of date, so the next plan proposes to revert. Updating only config leaves state stale.

#### Option C: Ignore a field permanently

For attributes legitimately managed by something else (cost tools, auto-tagging):

```hcl
resource "aws_instance" "legacy" {
  # ...
  lifecycle {
    ignore_changes = [tags["Owner"]]
  }
}
```

Use sparingly. It hides real drift for that field.

## Automating drift detection

### Exit codes

```bash
terraform plan -refresh-only -detailed-exitcode
echo $?
```

| Exit code | Meaning |
|---|---|
| `0` | No drift |
| `1` | Error |
| `2` | Drift detected |

Without `-detailed-exitcode`, `plan` returns 0 even when changes exist, so a script can't tell the difference.

### Nightly check with GitHub Actions

`.github/workflows/drift.yml`:

```yaml
name: drift-detection
on:
  schedule:
    - cron: "0 1 * * *"     # nightly at 01:00 UTC
  workflow_dispatch:         # manual runs

jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}   # read-only OIDC role
          aws-region: ap-southeast-2
      - run: terraform init
        working-directory: tf-import-lab
      - name: Check drift
        id: plan
        working-directory: tf-import-lab
        run: |
          set +e
          terraform plan -refresh-only -detailed-exitcode -no-color
          echo "code=$?" >> "$GITHUB_OUTPUT"
      - name: Fail on drift
        if: steps.plan.outputs.code != '0'
        run: exit 1
```

Requirements for this to work:

- **Remote state** (S3 plus DynamoDB lock, or HCP Terraform). A local state file in a Codespace is invisible to CI.
- **Read-only AWS credentials** for the CI role, since plan never needs write access.
- Alerts: a failed run notifies you; teams often add a Slack message or auto-created issue.

## Limitations of plan-based detection

- It **cannot find brand-new resources** created outside Terraform, because Terraform doesn't track them. Use `terraform query` (Terraform 1.14+), AWS Config or tag audits for those.
- A few attributes can't be read back from the provider and won't show drift.
- It only covers resources in the state you're running against. Run it per state or workspace.

## Real-world practice

1. Run drift checks on a schedule (nightly) in CI.
2. Investigate **why** before reverting. A console change during an incident may be a live fix.
3. Restrict console write access so changes go through Git and PRs.
4. Use `prevent_destroy` on critical resources.
5. Add policy checks (Sentinel, OPA, Checkov) in the pipeline.
6. HCP Terraform offers built-in scheduled health assessments if you use it.

## Common confusion

| Question | Answer |
|---|---|
| `plan -refresh-only` asked no confirmation. Did it update state? | No. It's read-only. Only `apply -refresh-only` writes to state. |
| I ran `apply -refresh-only` but plan still wants changes | Your config still differs from reality. Edit the config too. |
| `user_data_replace_on_change = false` appears in the plan | Harmless provider default added after import. Disappears after the next apply. |
| How do I revert drift? | `terraform apply` (normal, not refresh-only). |

## Golden rules

1. `plan -refresh-only` to **detect**, `apply` to **revert**, `apply -refresh-only` + config edit to **accept**.
2. Never accept drift in state only. Always update the config too.
3. Read the plan before every apply.
4. Automate detection, and keep CI credentials read-only.
5. Use remote state for any team or automation workflow.
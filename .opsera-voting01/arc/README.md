# Actions Runner Controller (ARC) Setup

Self-hosted GitHub Actions runners on your ArgoCD EKS cluster.

## Quick Start (PAT Method - Simplest)

```bash
# Make script executable
chmod +x .opsera-voting01/arc/scripts/setup-arc-pat.sh

# Run setup
./.opsera-voting01/arc/scripts/setup-arc-pat.sh
```

You'll need a GitHub PAT with these scopes:
- `repo` - Full control of private repositories
- `admin:org` - Organization administration (for org-level runners)

## GitHub App Method (Recommended for Production)

### Step 1: Create GitHub App

1. Go to: https://github.com/organizations/opsera-agent-demos/settings/apps/new
2. Fill in:
   - **Name**: `opsera-arc-runner`
   - **Homepage URL**: `https://github.com/opsera-agent-demos`
3. Set permissions:
   - **Repository permissions**:
     - Actions: Read
     - Metadata: Read
   - **Organization permissions**:
     - Self-hosted runners: Read & Write
4. Create the app
5. Generate and download a private key
6. Note the **App ID** from the app settings page
7. Install the app to your organization and note the **Installation ID** from the URL

### Step 2: Run Setup Script

```bash
chmod +x .opsera-voting01/arc/scripts/setup-arc-local.sh
./.opsera-voting01/arc/scripts/setup-arc-local.sh
```

## Files

```
.opsera-voting01/arc/
├── namespace.yaml           # Namespace for ARC
├── runner-deployment.yaml   # Runner deployment with autoscaler
├── serviceaccount.yaml      # RBAC for runners
├── helm-values.yaml         # ARC controller config
├── terraform/
│   ├── main.tf             # IRSA role for AWS access
│   ├── variables.tf
│   ├── outputs.tf
│   └── arc.tfvars
└── scripts/
    ├── setup-arc-local.sh  # GitHub App setup
    └── setup-arc-pat.sh    # PAT setup (simpler)
```

## Verify Installation

```bash
# Check controller
kubectl get deployment -n actions-runner-system

# Check runners
kubectl get runnerdeployment -n actions-runner-system

# Check pods
kubectl get pods -n actions-runner-system

# View in GitHub
open https://github.com/organizations/opsera-agent-demos/settings/actions/runners
```

## Using Self-Hosted Runners

Update your workflows to use the self-hosted runners:

```yaml
jobs:
  build:
    # Use self-hosted runner
    runs-on: [self-hosted, linux, opsera]
    # OR fallback to GitHub-hosted
    # runs-on: ubuntu-latest
```

## Troubleshooting

### Runners not appearing in GitHub

```bash
# Check controller logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller

# Check runner logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/component=runner
```

### Authentication errors

```bash
# Verify secret
kubectl get secret controller-manager -n actions-runner-system -o yaml

# Re-create secret
kubectl delete secret controller-manager -n actions-runner-system
# Then re-run setup script
```

## Cleanup

```bash
# Delete runners
kubectl delete runnerdeployment -n actions-runner-system --all

# Uninstall ARC
helm uninstall arc -n actions-runner-system

# Delete namespace
kubectl delete namespace actions-runner-system
```

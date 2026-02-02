#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# SETUP ARC LOCALLY
# Run this script to install Actions Runner Controller from your local machine
# ════════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
AWS_REGION="us-west-2"
HUB_CLUSTER="argocd-usw2"
ARC_NAMESPACE="actions-runner-system"
HELM_VERSION="0.27.6"
GITHUB_ORG="opsera-agent-demos"

echo "═══════════════════════════════════════════════════════════════"
echo "  Actions Runner Controller Setup"
echo "═══════════════════════════════════════════════════════════════"

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm required"; exit 1; }

# Configure kubectl
echo ""
echo "📡 Connecting to EKS cluster: ${HUB_CLUSTER}..."
aws eks update-kubeconfig --name ${HUB_CLUSTER} --region ${AWS_REGION}

# Create namespace
echo ""
echo "📦 Creating namespace..."
kubectl create namespace ${ARC_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Prompt for GitHub App credentials
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  GitHub App Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "You need a GitHub App for ARC authentication."
echo "Create one at: https://github.com/organizations/${GITHUB_ORG}/settings/apps/new"
echo ""
echo "Required permissions:"
echo "  - Repository: Actions (read), Metadata (read)"
echo "  - Organization: Self-hosted runners (read/write)"
echo ""

read -p "GitHub App ID: " GITHUB_APP_ID
read -p "GitHub App Installation ID: " GITHUB_APP_INSTALLATION_ID
read -p "Path to private key file: " GITHUB_APP_KEY_PATH

if [ ! -f "${GITHUB_APP_KEY_PATH}" ]; then
    echo "❌ Private key file not found: ${GITHUB_APP_KEY_PATH}"
    exit 1
fi

# Create secret
echo ""
echo "🔐 Creating GitHub App secret..."
kubectl delete secret controller-manager -n ${ARC_NAMESPACE} 2>/dev/null || true
kubectl create secret generic controller-manager \
    -n ${ARC_NAMESPACE} \
    --from-literal=github_app_id="${GITHUB_APP_ID}" \
    --from-literal=github_app_installation_id="${GITHUB_APP_INSTALLATION_ID}" \
    --from-file=github_app_private_key="${GITHUB_APP_KEY_PATH}"

# Add Helm repo
echo ""
echo "📦 Adding Helm repository..."
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Install ARC
echo ""
echo "🚀 Installing Actions Runner Controller..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm upgrade --install arc actions-runner-controller/actions-runner-controller \
    -n ${ARC_NAMESPACE} \
    -f "${SCRIPT_DIR}/../helm-values.yaml" \
    --version ${HELM_VERSION} \
    --wait --timeout 5m

# Wait for controller
echo ""
echo "⏳ Waiting for controller to be ready..."
kubectl rollout status deployment/arc-actions-runner-controller -n ${ARC_NAMESPACE} --timeout=120s

# Deploy runners
echo ""
echo "🏃 Deploying runners..."
kubectl apply -f "${SCRIPT_DIR}/../namespace.yaml"
kubectl apply -f "${SCRIPT_DIR}/../serviceaccount.yaml"
kubectl apply -f "${SCRIPT_DIR}/../runner-deployment.yaml"

# Wait for runners
echo ""
echo "⏳ Waiting for runners to register..."
for i in {1..30}; do
    READY=$(kubectl get runnerdeployment opsera-org-runners -n ${ARC_NAMESPACE} -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    echo "  Ready runners: ${READY:-0}"
    [ "${READY:-0}" -ge 1 ] && break
    sleep 10
done

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ ARC Installation Complete"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Controller:"
kubectl get deployment -n ${ARC_NAMESPACE}
echo ""
echo "Runner Deployments:"
kubectl get runnerdeployment -n ${ARC_NAMESPACE}
echo ""
echo "Runner Pods:"
kubectl get pods -n ${ARC_NAMESPACE} -l app.kubernetes.io/component=runner
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Next Steps"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. Verify runners in GitHub:"
echo "   https://github.com/organizations/${GITHUB_ORG}/settings/actions/runners"
echo ""
echo "2. Run bootstrap workflow:"
echo "   gh workflow run 00-bootstrap-infrastructure-voting01.yaml"
echo ""

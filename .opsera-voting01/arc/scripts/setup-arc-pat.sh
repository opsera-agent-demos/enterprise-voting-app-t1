#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# SETUP ARC WITH PAT (Simpler Alternative)
# Uses Personal Access Token instead of GitHub App
# ════════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
AWS_REGION="us-west-2"
HUB_CLUSTER="argocd-usw2"
ARC_NAMESPACE="actions-runner-system"
HELM_VERSION="0.27.6"
GITHUB_ORG="opsera-agent-demos"

echo "═══════════════════════════════════════════════════════════════"
echo "  Actions Runner Controller Setup (PAT Method)"
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

# Prompt for PAT
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Personal Access Token Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Create a PAT at: https://github.com/settings/tokens/new"
echo ""
echo "Required scopes:"
echo "  - repo (Full control of private repositories)"
echo "  - admin:org (for org-level runners)"
echo "  OR"
echo "  - admin:public_repo (for public repos only)"
echo ""

read -sp "GitHub PAT: " GITHUB_PAT
echo ""

# Create secret
echo ""
echo "🔐 Creating PAT secret..."
kubectl delete secret controller-manager -n ${ARC_NAMESPACE} 2>/dev/null || true
kubectl create secret generic controller-manager \
    -n ${ARC_NAMESPACE} \
    --from-literal=github_token="${GITHUB_PAT}"

# Add Helm repo
echo ""
echo "📦 Adding Helm repository..."
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Install ARC with PAT auth
echo ""
echo "🚀 Installing Actions Runner Controller..."
helm upgrade --install arc actions-runner-controller/actions-runner-controller \
    -n ${ARC_NAMESPACE} \
    --set syncPeriod=1m \
    --set authSecret.create=false \
    --set authSecret.name=controller-manager \
    --version ${HELM_VERSION} \
    --wait --timeout 5m

# Wait for controller
echo ""
echo "⏳ Waiting for controller to be ready..."
kubectl rollout status deployment/arc-actions-runner-controller -n ${ARC_NAMESPACE} --timeout=120s

# Deploy runners
echo ""
echo "🏃 Deploying runners..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "${SCRIPT_DIR}/../namespace.yaml"
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
kubectl get runnerdeployment -n ${ARC_NAMESPACE}
echo ""
kubectl get pods -n ${ARC_NAMESPACE}
echo ""
echo "Verify runners at:"
echo "  https://github.com/organizations/${GITHUB_ORG}/settings/actions/runners"
echo ""

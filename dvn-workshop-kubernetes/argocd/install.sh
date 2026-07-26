#!/bin/bash
# =============================================================================
# ArgoCD Installation Script — ADR-006
# Instala o ArgoCD no cluster EKS e configura a Application para GitOps.
# =============================================================================
set -euo pipefail

NAMESPACE="argocd"
ARGOCD_VERSION="stable"
MANIFESTS_REPO_URL="https://github.com/wendel1w/workshop-july.git"
TARGET_REVISION="main"
DEST_NAMESPACE="default"
APP_NAME="dvn-workshop"

echo "============================================"
echo " ArgoCD Installation — ADR-006"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# Passo 1: Criar namespace e instalar ArgoCD
# -----------------------------------------------------------------------------
echo "[1/5] Criando namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[1/5] Instalando ArgoCD (version: ${ARGOCD_VERSION})..."
kubectl apply -n "${NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "[1/5] Aguardando pods do ArgoCD ficarem prontos..."
kubectl wait --for=condition=Available deployment/argocd-server \
  -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=Available deployment/argocd-repo-server \
  -n "${NAMESPACE}" --timeout=300s
kubectl wait --for=condition=Available deployment/argocd-application-controller \
  -n "${NAMESPACE}" --timeout=300s 2>/dev/null || true

echo ""
echo "[1/5] ✅ ArgoCD instalado com sucesso!"
echo ""

# -----------------------------------------------------------------------------
# Passo 2: Obter senha inicial do admin
# -----------------------------------------------------------------------------
echo "[2/5] Obtendo senha inicial do admin..."
ADMIN_PASSWORD=$(kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo ""
echo "  👤 Username: admin"
echo "  🔑 Password: ${ADMIN_PASSWORD}"
echo ""
echo "  ⚠️  Troque a senha após o primeiro login!"
echo ""

# -----------------------------------------------------------------------------
# Passo 3: Aplicar a Application CRD
# -----------------------------------------------------------------------------
echo "[3/5] Criando Application '${APP_NAME}'..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${MANIFESTS_REPO_URL}
    targetRevision: ${TARGET_REVISION}
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: ${DEST_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
EOF

echo ""
echo "[3/5] ✅ Application '${APP_NAME}' criada!"
echo ""

# -----------------------------------------------------------------------------
# Passo 4: Verificar status
# -----------------------------------------------------------------------------
echo "[4/5] Verificando status da Application..."
sleep 5
kubectl get applications -n "${NAMESPACE}"
echo ""

# -----------------------------------------------------------------------------
# Passo 5: Instrucoes de acesso
# -----------------------------------------------------------------------------
echo "[5/5] Instrucoes de acesso à UI:"
echo ""
echo "  Execute o port-forward:"
echo "    kubectl port-forward svc/argocd-server -n ${NAMESPACE} 8080:443"
echo ""
echo "  Acesse no navegador:"
echo "    https://localhost:8080"
echo ""
echo "  Login:"
echo "    Username: admin"
echo "    Password: (exibida acima)"
echo ""
echo "============================================"
echo " Instalacao concluida!"
echo "============================================"

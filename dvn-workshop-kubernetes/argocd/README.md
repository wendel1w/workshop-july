# ArgoCD — Instalação e Configuração (ADR-006)

## Pré-requisitos

- Cluster EKS operacional e acessível via `kubectl`
- `kubectl` configurado com contexto do cluster `dvn-wendel-eks`

## Instalação Rápida

```bash
chmod +x install.sh
./install.sh
```

O script executa:
1. Cria o namespace `argocd`
2. Instala o ArgoCD via manifests oficiais (versão stable)
3. Aguarda todos os pods ficarem prontos
4. Exibe a senha inicial do admin
5. Cria a Application `dvn-workshop` com auto-sync

## Instalação Manual (passo a passo)

```bash
# 1. Criar namespace
kubectl create namespace argocd

# 2. Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Aguardar pods
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# 4. Obter senha
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 5. Criar Application
kubectl apply -f application.yaml
```

## Acesso à UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acesse: https://localhost:8080
- Username: `admin`
- Password: (obtida no passo 4)

## Repositório Privado

Se o repositório `dvn-workshop-kubernetes` for privado, configure as credenciais:

```bash
# Editar o arquivo com as credenciais reais
vim repo-secret.yaml

# Aplicar
kubectl apply -f repo-secret.yaml
```

## Verificação

```bash
# Status da Application
kubectl get applications -n argocd

# Pods das aplicações
kubectl get pods -n default

# Logs do controller
kubectl logs -n argocd deployment/argocd-application-controller
```

## Desinstalação

```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

> As aplicações continuam rodando após a remoção do ArgoCD.

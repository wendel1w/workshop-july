# Rule: ECR Build & Push

**Escopo:** build de imagens Docker e push para Amazon ECR a partir deste repositório.
**Objetivo:** procedimento padronizado para autenticação no ECR, build e push de imagens, com suporte a múltiplas aplicações em paralelo.

## 1. Princípios Obrigatórios

- **Login obrigatório antes de push:** autenticar no ECR via `aws ecr get-login-password` antes de qualquer push.
- **Tag imutável:** toda imagem deve ser taggeada com o git SHA curto + tag semântica (latest, versão).
- **Repositório pré-existente:** o repositório ECR deve existir antes do push. Criar via Terraform se necessário.
- **Build paralelo:** quando há múltiplas aplicações, construir e enviar simultaneamente usando `&` e `wait`.
- **Validação pós-push:** confirmar que a imagem está disponível no ECR após o push.
- **Sem credenciais em variáveis:** nunca armazenar tokens em variáveis de ambiente persistentes ou arquivos.

## 2. Pré-requisitos

| Requisito | Como verificar |
|---|---|
| AWS CLI v2 instalado | `aws --version` |
| Docker daemon rodando | `docker info` |
| Credenciais AWS configuradas | `aws sts get-caller-identity` |
| Permissões IAM necessárias | `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` |

## 3. Variáveis Padrão

Definir no início de qualquer script de build & push:

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
```

## 4. Login no ECR

O token de autenticação do ECR expira em **12 horas**. Executar antes de qualquer push:

```bash
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}
```

**Verificação de sucesso:** o comando deve retornar `Login Succeeded`.

**NUNCA:**
- Armazenar o token em variável ou arquivo.
- Usar `docker login` com `-p` (expõe o token no histórico do shell).
- Fazer login em scripts com `set -x` ativo (expõe o token nos logs).

## 5. Criação de Repositórios ECR (se necessário)

Antes do primeiro push para um novo repositório:

```bash
aws ecr describe-repositories --repository-names "${REPO_NAME}" --region ${AWS_REGION} 2>/dev/null || \
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE
```

**Convenção de nomes de repositório:** `<project>/<app-name>` em kebab-case.
Exemplo: `dvn-workshop/backend`, `dvn-workshop/frontend`.

## 6. Build & Tag

```bash
# Build com tag git SHA + latest
docker build -t ${ECR_REGISTRY}/${REPO_NAME}:${GIT_SHA} \
             -t ${ECR_REGISTRY}/${REPO_NAME}:latest \
             -f <path-to-Dockerfile> <build-context>
```

**Regras de tagging:**
- `:<git-sha>` — identificação imutável do build (rastreabilidade).
- `:latest` — convenção para deploy contínuo (sobrescrito a cada push).
- `:<version>` — tag semântica (ex.: `v1.2.3`) quando houver release.

## 7. Push

```bash
docker push ${ECR_REGISTRY}/${REPO_NAME}:${GIT_SHA}
docker push ${ECR_REGISTRY}/${REPO_NAME}:latest
```

Ou push de todas as tags de uma vez:

```bash
docker push ${ECR_REGISTRY}/${REPO_NAME} --all-tags
```

## 8. Build & Push Simultâneo (Múltiplas Aplicações)

Quando há múltiplas aplicações para construir, usar execução paralela:

```bash
#!/bin/bash
set -euo pipefail

# --- Variáveis ---
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")

# --- Login ECR (uma vez, antes de todos os builds) ---
echo "==> Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# --- Definir aplicações: REPO_NAME|DOCKERFILE_PATH|BUILD_CONTEXT ---
APPS=(
  "dvn-workshop/backend|dvn-workshop-julho/dvn-workshop-apps/backend/YoutubeLiveApp/Dockerfile|dvn-workshop-julho/dvn-workshop-apps/backend/YoutubeLiveApp"
  "dvn-workshop/frontend|dvn-workshop-julho/dvn-workshop-apps/frontend/youtube-live-app/Dockerfile|dvn-workshop-julho/dvn-workshop-apps/frontend/youtube-live-app"
)

# --- Função de build & push por app ---
build_and_push() {
  local app_def="$1"
  local repo_name=$(echo "${app_def}" | cut -d'|' -f1)
  local dockerfile=$(echo "${app_def}" | cut -d'|' -f2)
  local context=$(echo "${app_def}" | cut -d'|' -f3)

  echo "==> [${repo_name}] Building..."
  docker build -t ${ECR_REGISTRY}/${repo_name}:${GIT_SHA} \
               -t ${ECR_REGISTRY}/${repo_name}:latest \
               -f ${dockerfile} ${context}

  echo "==> [${repo_name}] Pushing..."
  docker push ${ECR_REGISTRY}/${repo_name}:${GIT_SHA}
  docker push ${ECR_REGISTRY}/${repo_name}:latest

  echo "==> [${repo_name}] Done!"
}

# --- Executar builds em paralelo ---
echo "==> Starting parallel builds..."
PIDS=()
for app in "${APPS[@]}"; do
  build_and_push "${app}" &
  PIDS+=($!)
done

# --- Aguardar todos os builds ---
FAILED=0
for pid in "${PIDS[@]}"; do
  if ! wait ${pid}; then
    FAILED=$((FAILED + 1))
  fi
done

if [ ${FAILED} -gt 0 ]; then
  echo "ERROR: ${FAILED} build(s) failed!"
  exit 1
fi

echo "==> All builds completed successfully!"
```

**Notas sobre paralelismo:**
- O login no ECR é feito **uma vez** antes de todos os builds (token compartilhado).
- Cada build & push roda em background (`&`) com PID rastreado.
- O script aguarda todos os processos (`wait`) e reporta falhas.
- Docker builds paralelos competem por CPU/IO — em máquinas com poucos cores, o ganho pode ser limitado.
- Em CI/CD (GitHub Actions, GitLab CI), preferir matrix/parallel jobs nativos da plataforma.

## 9. Validação Pós-Push

Após o push, verificar que a imagem está disponível:

```bash
aws ecr describe-images \
  --repository-name "${REPO_NAME}" \
  --image-ids imageTag="${GIT_SHA}" \
  --region ${AWS_REGION} \
  --query 'imageDetails[0].{pushedAt:imagePushedAt,size:imageSizeInBytes,tags:imageTags}' \
  --output table
```

**Critérios de aceite:**
- Imagem existe com a tag `${GIT_SHA}`.
- `imagePushedAt` é recente (últimos minutos).
- `imageTags` contém tanto o SHA quanto `latest`.

## 10. Script Completo para uma Aplicação

Para build & push de uma única aplicação:

```bash
#!/bin/bash
set -euo pipefail

# --- Configuração ---
APP_NAME="${1:?Uso: $0 <app-name> <dockerfile-path> <build-context>}"
DOCKERFILE="${2:?Caminho do Dockerfile necessário}"
BUILD_CONTEXT="${3:?Build context necessário}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
REPO_NAME="dvn-workshop/${APP_NAME}"

# --- Login ---
echo "==> Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# --- Garantir que o repositório existe ---
aws ecr describe-repositories --repository-names "${REPO_NAME}" --region ${AWS_REGION} 2>/dev/null || \
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE

# --- Build ---
echo "==> Building ${REPO_NAME}:${GIT_SHA}..."
docker build -t ${ECR_REGISTRY}/${REPO_NAME}:${GIT_SHA} \
             -t ${ECR_REGISTRY}/${REPO_NAME}:latest \
             -f ${DOCKERFILE} ${BUILD_CONTEXT}

# --- Push ---
echo "==> Pushing ${REPO_NAME}..."
docker push ${ECR_REGISTRY}/${REPO_NAME}:${GIT_SHA}
docker push ${ECR_REGISTRY}/${REPO_NAME}:latest

# --- Validação ---
echo "==> Verifying push..."
aws ecr describe-images \
  --repository-name "${REPO_NAME}" \
  --image-ids imageTag="${GIT_SHA}" \
  --region ${AWS_REGION} \
  --query 'imageDetails[0].imageTags' \
  --output text

echo "==> Done! Image: ${ECR_REGISTRY}/${REPO_NAME}:${GIT_SHA}"
```

## 11. Troubleshooting

| Problema | Causa provável | Solução |
|---|---|---|
| `no basic auth credentials` | Token expirado ou login não executado | Refazer `aws ecr get-login-password \| docker login` |
| `repository does not exist` | Repositório ECR não criado | Criar via `aws ecr create-repository` ou Terraform |
| `denied: Your authorization token has expired` | Token > 12h | Refazer login |
| `toomanyrequests: Rate exceeded` | Throttling do ECR | Aguardar e retry com backoff exponencial |
| `image tag already exists` (com IMMUTABLE) | Tag imutável habilitada | Usar tag diferente ou trocar para MUTABLE |
| Build paralelo falha por OOM | Docker daemon sem memória | Reduzir paralelismo ou aumentar memória |

## 12. Integração com o Projeto

Para este repositório (`dvn-workshop`), as aplicações são:

| Aplicação | Repositório ECR | Dockerfile | Build Context |
|---|---|---|---|
| Backend (.NET 8) | `dvn-workshop/backend` | `dvn-workshop-julho/dvn-workshop-apps/backend/YoutubeLiveApp/Dockerfile` | `dvn-workshop-julho/dvn-workshop-apps/backend/YoutubeLiveApp` |
| Frontend (Next.js) | `dvn-workshop/frontend` | `dvn-workshop-julho/dvn-workshop-apps/frontend/youtube-live-app/Dockerfile` | `dvn-workshop-julho/dvn-workshop-apps/frontend/youtube-live-app` |

## 13. Checklist de Execução

Antes de rodar o build & push, validar:

- [ ] AWS CLI instalado e credenciais ativas (`aws sts get-caller-identity`)
- [ ] Docker daemon rodando (`docker info`)
- [ ] Dockerfile existe e está validado (build local funciona)
- [ ] Repositório ECR existe ou o script tem permissão para criar
- [ ] Rede com acesso ao ECR (endpoint `*.dkr.ecr.*.amazonaws.com`)
- [ ] Disco com espaço suficiente para imagens (~500MB–1GB por app)
- [ ] Login no ECR executado (token válido por 12h)

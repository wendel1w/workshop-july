# ADR-006: Instalação e Configuração do ArgoCD no Cluster EKS

| Campo | Valor |
|---|---|
| **Status** | Aguardando Aprovação |
| **Data** | 2026-07-26 |
| **Autor** | Arquiteto de Soluções (agente) |
| **Aprovado por** | _(preenchido manualmente pelo revisor humano)_ |
| **Data da aprovação** | _(preenchido manualmente)_ |
| **Escopo** | Cluster EKS dvn-wendel-prd / us-east-1 / namespace argocd |

> **Gate de implementação:** este ADR só pode ser implementado quando o status for
> `Aprovado para Implementação`.

## 1. Contexto

A estratégia de deploy contínuo adotada neste projeto segue o padrão **GitOps**: a pipeline CI (ADR-005) atualiza as imagens no repositório de manifests (`dvn-workshop-kubernetes`), e um operador GitOps dentro do cluster sincroniza o estado desejado (repo) com o estado real (cluster).

O ArgoCD é o operador GitOps escolhido para:
- Monitorar o repositório `dvn-workshop-kubernetes`.
- Detectar mudanças no `kustomization.yaml` (novas image tags).
- Aplicar automaticamente os manifests no cluster EKS.

Atualmente o cluster EKS (ADR-003) está provisionado mas não possui nenhum operador GitOps instalado.

## 2. Requisitos

- **Funcionais:**
  - ArgoCD instalado no cluster EKS no namespace `argocd`.
  - Application CRD configurado para monitorar o repo `dvn-workshop-kubernetes`, branch `main`, path `/` (raiz do kustomization).
  - Sync automático habilitado (auto-sync com self-heal e prune).
  - Acesso à UI do ArgoCD para visualização do estado dos deployments.

- **Não funcionais:**
  - Disponibilidade: ArgoCD server com pelo menos 1 réplica (ambiente workshop, sem HA).
  - Segurança: acesso à UI apenas via port-forward ou ingress com autenticação.
  - Observabilidade: logs do ArgoCD acessíveis via kubectl.
  - Recursos: footprint mínimo no cluster (workshop com 2 nodes t3.medium).

## 3. Premissas

| # | Premissa | Confirmável com |
|---|---|---|
| 1 | O cluster EKS está operacional e acessível via kubectl. | `kubectl cluster-info` |
| 2 | O repo `dvn-workshop-kubernetes` é público ou ArgoCD tem credenciais para acessá-lo. | Verificar visibilidade do repo |
| 3 | O namespace padrão dos apps é `default` (conforme manifests existentes). | Confirmado via kustomization.yaml |
| 4 | O cluster tem recursos disponíveis para o ArgoCD (~300MB RAM, ~200m CPU). | 2x t3.medium = 4GB RAM total |
| 5 | A versão do ArgoCD será a stable mais recente (v2.x). | Verificar release page |
| 6 | Para ambiente workshop, instalação non-HA é aceitável. | Confirmar com o usuário |

## 4. Alternativas Consideradas

| Opção | Prós | Contras | Custo relativo | Veredito |
|---|---|---|---|---|
| **A) ArgoCD (instalação direta via manifests oficiais)** | Padrão de mercado, UI rica, CRD nativo, grande comunidade, suporte a Kustomize nativo | Footprint maior que Flux (~300MB RAM) | Gratuito (open source) | **Escolhida** |
| B) Flux CD v2 | Mais leve, GitOps toolkit modular, menor footprint | Sem UI nativa (precisa Weave GitOps), menor adoção em workshops | Gratuito | Descartada — UI é importante para visibilidade em workshop |
| C) Pipeline faz kubectl apply direto | Simples | Anti-pattern GitOps, pipeline precisa de acesso ao cluster, sem self-heal, sem drift detection | Gratuito | Descartada — viola princípios GitOps |
| D) ArgoCD via Helm chart | Flexível, customizável | Mais complexo para instalar, precisa Helm instalado | Gratuito | Alternativa válida, mas manifests oficiais são suficientes para workshop |

**Decisão sobre método de instalação:**

| Método | Prós | Contras | Veredito |
|---|---|---|---|
| **Manifests oficiais (`install.yaml`)** | Um comando, versionado, simples | Menos customizável que Helm | **Escolhido** (adequado para workshop) |
| Helm chart (argo-helm) | Altamente customizável, values.yaml | Mais complexo, precisa helm | Alternativa para produção |
| Terraform (kubernetes provider) | Idempotente, state | Frágil para CRDs, manifests grandes | Descartada |

## 5. Decisão

Instalar o **ArgoCD v2.x (stable)** via manifests oficiais (`install.yaml`) no namespace `argocd`, com:
- **Auto-sync** habilitado na Application.
- **Self-heal** para corrigir drift automaticamente.
- **Prune** para remover recursos órfãos.
- Acesso à UI via `kubectl port-forward` (adequado para workshop; sem ingress público).
- Repositório configurado como **Application** CRD apontando para `dvn-workshop-kubernetes`.

**Justificativa Well-Architected:**
- **Excelência Operacional:** GitOps garante que o cluster sempre reflete o estado do repositório; deploys são auditáveis via git history.
- **Confiabilidade:** self-heal corrige drift automático; estado declarativo é reprodutível.
- **Segurança:** o cluster faz pull do repo (não precisa expor API server para CI); credenciais do repo ficam dentro do cluster.
- **Performance:** sync é event-driven (webhook) ou polling (3min default), sem carga no CI.

## 6. Arquitetura Proposta

```mermaid
flowchart LR
    subgraph GitHub
        REPO[dvn-workshop-kubernetes<br/>kustomization.yaml]
    end

    subgraph EKS Cluster
        subgraph ns:argocd
            SERVER[argocd-server]
            CTRL[argocd-application-controller]
            REPO_SRV[argocd-repo-server]
        end
        subgraph ns:default
            FE[frontend Deployment]
            BE[backend Deployment]
        end
    end

    REPO_SRV -->|git pull / polling 3min| REPO
    CTRL -->|compara desired vs live| FE & BE
    CTRL -->|kubectl apply| FE & BE
    SERVER -->|UI port-forward :8080| USER[Developer]
```

**Componentes do ArgoCD:**
- **argocd-server:** API server + UI web.
- **argocd-application-controller:** monitora Applications, detecta diff, executa sync.
- **argocd-repo-server:** clona e renderiza manifests (suporta Kustomize nativamente).
- **argocd-redis:** cache interno.
- **argocd-dex-server:** SSO (opcional, não usado em workshop).

## 7. Layout de Diretórios

```
dvn-workshop-kubernetes/                # Repo monitorado pelo ArgoCD
├── kustomization.yaml                  # Root: references backend/ e frontend/
├── backend/
│   ├── kustomization.yaml              # images: [...] atualizado pelo CI
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pdb.yaml
└── frontend/
    ├── kustomization.yaml              # images: [...] atualizado pelo CI
    ├── deployment.yaml
    ├── service.yaml
    └── pdb.yaml
```

Nota: O ArgoCD será instalado via `kubectl apply` com manifests oficiais, sem diretório dedicado no repo de IaC. A Application CRD será aplicada manualmente (um-time setup).

## 8. Plano de Implementação

### Passo 1 — Criar namespace e instalar ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Critério de aceite:**
- `kubectl get pods -n argocd` mostra todos os pods em `Running` (5 pods: server, controller, repo-server, redis, dex-server).
- `kubectl get svc -n argocd argocd-server` retorna o service.

### Passo 2 — Obter senha inicial do admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Critério de aceite:** senha retornada pode ser usada para login na UI.

### Passo 3 — Acessar a UI via port-forward

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acessar em `https://localhost:8080` (aceitar certificado self-signed). Login: `admin` + senha do passo anterior.

**Critério de aceite:** UI acessível e login funcional.

### Passo 4 — Instalar ArgoCD CLI (opcional, para automação)

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

**Critério de aceite:** `argocd version` retorna versão do client.

### Passo 5 — Criar a Application CRD

Aplicar o manifesto da Application que aponta para o repositório de manifests:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dvn-workshop
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/dvn-workshop-kubernetes.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
```

**Critério de aceite:**
- `kubectl get applications -n argocd` mostra `dvn-workshop` com status `Synced` e `Healthy`.
- Os pods de frontend e backend estão rodando no namespace `default`.

### Passo 6 — Configurar credenciais do repositório (se privado)

Se o repositório `dvn-workshop-kubernetes` for privado:

```bash
argocd repo add https://github.com/<org>/dvn-workshop-kubernetes.git \
  --username <username> \
  --password <PAT>
```

Ou via Secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-dvn-workshop-kubernetes
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/<org>/dvn-workshop-kubernetes.git
  username: <username>
  password: <PAT>
```

**Critério de aceite:** ArgoCD consegue clonar e renderizar os manifests (visible no status da Application).

### Passo 7 — Validar fluxo end-to-end

1. Fazer push de alteração no repo de manifests (simular o que a pipeline faz).
2. Aguardar até 3 minutos (polling interval) ou forçar sync na UI.
3. Verificar que os pods foram atualizados com a nova imagem.

**Critério de aceite:**
- `kubectl get pods -n default -o jsonpath='{.items[*].spec.containers[*].image}'` mostra a nova tag.
- Application status no ArgoCD é `Synced` + `Healthy`.

### Passo 8 — (Opcional) Configurar webhook para sync imediato

Para evitar esperar o polling de 3min, configurar webhook do GitHub no ArgoCD:

1. No repo `dvn-workshop-kubernetes`, Settings → Webhooks → Add webhook.
2. Payload URL: `https://<argocd-server-url>/api/webhook` (requer ArgoCD exposto via ingress ou tunnel).
3. Content type: `application/json`.
4. Events: `push`.

**Nota:** para workshop com port-forward, o webhook não é viável. O polling de 3min é suficiente.

**Critério de aceite:** (se configurado) push no repo dispara sync em < 10 segundos.

## 9. Boas Práticas Aplicadas

- **Namespace dedicado:** ArgoCD em `argocd`, apps em `default` — separação clara.
- **Auto-sync + self-heal:** garante que o cluster converge para o estado desejado mesmo após alterações manuais.
- **Prune habilitado:** recursos removidos do repo são removidos do cluster.
- **Kustomize nativo:** ArgoCD renderiza Kustomize sem necessidade de hooks ou plugins.
- **Acesso mínimo:** UI via port-forward (não exposta à internet).
- **Senha inicial:** deve ser trocada após primeiro login (ou deletar o secret `argocd-initial-admin-secret`).
- **Observabilidade:** ArgoCD expõe métricas Prometheus (port 8082) para monitoramento futuro.

## 10. Segurança e Compliance

| Aspecto | Decisão |
|---|---|
| Exposição à internet | **Nenhuma** — UI via port-forward apenas; sem Ingress público |
| Autenticação UI | Admin local com senha (adequado para workshop) |
| RBAC ArgoCD | Default (admin tem full access); em produção, configurar SSO + RBAC |
| Credenciais do repo | Secret no namespace `argocd`, acessível apenas pelo controller |
| Network policy | ArgoCD precisa de egress para GitHub (HTTPS 443) |
| Cluster admin | ArgoCD roda com ClusterRole (necessário para aplicar em qualquer namespace) |
| Criptografia | TLS entre ArgoCD components; comunicação com repo via HTTPS |

**Ponto de atenção:** ArgoCD com `cluster-admin` é poderoso. Em produção, limitar via AppProject + destination restrictions. Para workshop, aceitável.

## 11. Custo Estimado

| Componente | Custo |
|---|---|
| ArgoCD (open source) | Gratuito |
| Recursos no cluster (~300MB RAM, ~200m CPU) | Já incluído nos nodes existentes (t3.medium) |
| Tráfego egress (git poll a cada 3min) | Desprezível (< $0.01/mês) |
| **Total** | **$0/mês** (consumo de recursos já provisionados) |

**Nota:** o footprint do ArgoCD (~300MB RAM) é significativo considerando que o cluster tem 2x t3.medium (4GB RAM cada, ~3.5GB allocatable). Considerar que as apps + ArgoCD + system pods devem caber nos 7GB allocatable totais.

## 12. Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|---|---|---|---|
| ArgoCD consome RAM excessiva em cluster pequeno | Alto — OOMKill de pods | Média | Monitorar `kubectl top pods -n argocd`; configurar resource limits se necessário |
| Repo privado sem credenciais configuradas | Médio — sync falha | Baixa (one-time setup) | Passo 6 do plano de implementação |
| Self-heal desfaz alteração manual intencional | Baixo — comportamento esperado | Média | Educação: alterações devem ser via repo, nunca `kubectl edit` direto |
| ArgoCD server crash | Médio — sem sync até recovery | Baixa | 1 réplica é suficiente para workshop; em produção, HA com 3 réplicas |
| Polling de 3min atrasa deploy | Baixo — deploy não é instant | Alta (by design) | Aceitável para workshop; webhook se necessário |
| Drift entre Application e repo (ex.: branch deletado) | Médio — Application fica `Unknown` | Baixa | Monitorar status; não deletar branch `main` |

## 13. Consequências

- **Positivas:**
  - Deploy contínuo totalmente GitOps: o cluster é reflexo do repositório.
  - Visibilidade do estado de cada app via UI do ArgoCD.
  - Rollback simples: revert no repo → ArgoCD faz sync automático.
  - Self-heal protege contra alterações acidentais no cluster.
  - Kustomize suportado nativamente, sem plugin extra.

- **Negativas / dívida técnica assumida:**
  - ArgoCD instalado via `kubectl apply` (não via Helm/Terraform) — dificulta upgrade automatizado.
  - Sem HA (single replica) — aceitável para workshop.
  - Sem SSO/RBAC avançado — aceitável para workshop.
  - ClusterRole ampla — limitar em produção.

- **Plano de rollback:**
  - `kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
  - `kubectl delete namespace argocd`
  - As aplicações continuam rodando (ArgoCD não afeta pods já deployed).

## 14. Decisão de Aprovação

_(preenchido pelo revisor humano — motivo em caso de `Não Aprovado`, ressalvas em caso de aprovação)_

## 15. Histórico de Revisões

| Versão | Data | Alteração | Motivo |
|---|---|---|---|
| 1.0 | 2026-07-26 | Criação inicial | Solicitação do usuário |

## 16. Referências

- [ArgoCD — Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD — Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [ArgoCD — Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [ArgoCD — Kustomize Support](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [ArgoCD GitHub Releases](https://github.com/argoproj/argo-cd/releases)
- ADR-003: EKS Cluster Stack (infraestrutura base)
- ADR-005: Pipeline CI/CD GitHub Actions (upstream — gera commits no repo de manifests)

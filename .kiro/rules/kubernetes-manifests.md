# Rule: Padrões de Manifestos Kubernetes

**Escopo:** geração de manifestos Kubernetes (Deployments, Services, PodDisruptionBudgets) para qualquer aplicação deste repositório.
**Objetivo:** garantir alta disponibilidade, observabilidade e conformidade com boas práticas desde o primeiro deploy.

## 1. Princípios Obrigatórios

Todo manifesto Kubernetes gerado DEVE seguir estes princípios, sem exceção:

- **Deployment + Service + PDB:** sempre criar os três recursos juntos.
- **Service tipo NodePort:** todo Deployment deve ter um Service NodePort associado.
- **Labels padronizadas:** usar labels recomendadas pelo Kubernetes (`app.kubernetes.io/*`).
- **Probes obrigatórias:** todo container deve ter `readinessProbe` e `livenessProbe`.
- **Mínimo de 2 réplicas:** nunca menos que 2 pods para garantir disponibilidade.
- **PodDisruptionBudget:** sempre definir um PDB para proteger contra evictions simultâneas.
- **Recursos definidos:** sempre especificar `requests` e `limits` de CPU e memória.

## 2. Labels Obrigatórias

Usar o padrão [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/):

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <nome-do-app>
    app.kubernetes.io/version: <versao>
    app.kubernetes.io/component: <componente>  # backend, frontend, worker, database
    app.kubernetes.io/part-of: <sistema>       # nome do sistema/projeto
    app.kubernetes.io/managed-by: kubectl      # ou helm, argocd, etc.
```

**Regras:**
- `app.kubernetes.io/name` — nome curto da aplicação (ex.: `backend`, `frontend`).
- `app.kubernetes.io/version` — versão da imagem ou git SHA (ex.: `latest`, `v1.2.3`).
- `app.kubernetes.io/component` — papel funcional no sistema.
- `app.kubernetes.io/part-of` — nome do projeto/sistema maior (ex.: `dvn-workshop`).
- `app.kubernetes.io/managed-by` — ferramenta que gerencia o recurso.

O **selector** do Deployment e Service deve usar apenas `app.kubernetes.io/name` (imutável após criação).

## 3. Estrutura do Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/version: "<version>"
    app.kubernetes.io/component: <component>
    app.kubernetes.io/part-of: <project>
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 2  # MINIMO OBRIGATÓRIO: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
        app.kubernetes.io/version: "<version>"
        app.kubernetes.io/component: <component>
        app.kubernetes.io/part-of: <project>
    spec:
      containers:
        - name: <app-name>
          image: <image-uri>:<tag>
          ports:
            - containerPort: <porta>
              protocol: TCP
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: <health-path>
              port: <porta>
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: <health-path>
              port: <porta>
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3
```

## 4. Estrutura do Service (NodePort)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/component: <component>
    app.kubernetes.io/part-of: <project>
    app.kubernetes.io/managed-by: kubectl
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: <app-name>
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: <porta-do-container>
```

**Notas:**
- Não fixar `nodePort` — deixar o Kubernetes alocar automaticamente (range 30000-32767).
- O `port` do Service é a porta exposta internamente no cluster (geralmente 80).
- O `targetPort` é a porta do container definida no Deployment.

## 5. Estrutura do PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/part-of: <project>
    app.kubernetes.io/managed-by: kubectl
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
```

**Regras do PDB:**
- Com 2 réplicas: usar `minAvailable: 1` (permite 1 pod ser evicted por vez).
- Com 3+ réplicas: usar `minAvailable: 2` ou `maxUnavailable: 1`.
- O selector DEVE corresponder exatamente ao selector do Deployment.

## 6. Regras de Probes

### readinessProbe
- **Propósito:** indica se o pod está pronto para receber tráfego.
- **Consequência de falha:** pod é removido do Service (para de receber requests).
- **Configuração padrão:**
  - `initialDelaySeconds: 5` — tempo para a app inicializar.
  - `periodSeconds: 10` — frequência de check.
  - `failureThreshold: 3` — tentativas antes de marcar como não-pronto.

### livenessProbe
- **Propósito:** indica se o pod está vivo (não travou/deadlock).
- **Consequência de falha:** pod é reiniciado pelo kubelet.
- **Configuração padrão:**
  - `initialDelaySeconds: 15` — dar mais tempo que o readiness antes de começar a checar.
  - `periodSeconds: 20` — menos frequente que readiness (evitar restarts desnecessários).
  - `failureThreshold: 3` — tentativas antes de restart.

### Ajustes por linguagem

| Linguagem | readiness.initialDelaySeconds | liveness.initialDelaySeconds | Observação |
|---|---|---|---|
| Node.js | 5 | 10 | Cold start rápido |
| .NET | 5 | 15 | Cold start moderado |
| Go | 3 | 10 | Cold start mínimo |
| Java/Spring | 15 | 30 | Cold start lento (JVM warmup) |
| Python | 5 | 15 | Cold start rápido |

### Endpoint de health
- O endpoint usado nas probes DEVE retornar HTTP 200 quando saudável.
- Usar o mesmo endpoint para readiness e liveness é aceitável para apps simples.
- Para apps complexas, considerar endpoints separados (`/ready` vs `/health`).

## 7. Regras de Recursos (requests/limits)

| Tipo de app | CPU request | CPU limit | Memory request | Memory limit |
|---|---|---|---|---|
| Frontend (Next.js, React) | 100m | 500m | 128Mi | 256Mi |
| Backend (API REST leve) | 100m | 500m | 128Mi | 512Mi |
| Backend (Java/Spring) | 250m | 1000m | 512Mi | 1Gi |
| Worker/Job | 200m | 1000m | 256Mi | 512Mi |

**Regras:**
- `requests` = o que o pod precisa para funcionar normalmente (garante scheduling).
- `limits` = o máximo que o pod pode consumir (previne noisy neighbor).
- Nunca omitir `requests` — pods sem requests são classificados como BestEffort (primeiros a serem evicted).

## 8. Organização dos Arquivos

Para cada aplicação, gerar um único arquivo YAML multi-document:

```
k8s/
├── backend.yaml    # Deployment + Service + PDB do backend
└── frontend.yaml   # Deployment + Service + PDB do frontend
```

**Formato do arquivo:**

```yaml
# --- Deployment ---
apiVersion: apps/v1
kind: Deployment
...
---
# --- Service ---
apiVersion: v1
kind: Service
...
---
# --- PodDisruptionBudget ---
apiVersion: policy/v1
kind: PodDisruptionBudget
...
```

Separar recursos com `---` no mesmo arquivo. Ordem: Deployment → Service → PDB.

## 9. Integração com este Projeto

Para as aplicações do `dvn-workshop`:

| Aplicação | app.kubernetes.io/name | Porta | Health Path | Image |
|---|---|---|---|---|
| Backend (.NET 8) | `backend` | 8080 | `/backend/health` | `725510651649.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/backend:latest` |
| Frontend (Next.js) | `frontend` | 3000 | `/api/health` | `725510651649.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/frontend:latest` |

Valores comuns:
- `app.kubernetes.io/part-of: dvn-workshop`
- `app.kubernetes.io/managed-by: kubectl`
- `namespace: default` (workshop; em produção usar namespaces dedicados)

## 10. Checklist de Revisão

Antes de aplicar qualquer manifesto, validar:

- [ ] Deployment com `replicas >= 2`
- [ ] Labels `app.kubernetes.io/*` presentes em todos os recursos
- [ ] Selector consistente entre Deployment, Service e PDB
- [ ] `readinessProbe` configurada com endpoint HTTP válido
- [ ] `livenessProbe` configurada com `initialDelaySeconds` > `readinessProbe`
- [ ] `resources.requests` e `resources.limits` definidos
- [ ] Service tipo `NodePort` com `targetPort` correto
- [ ] PodDisruptionBudget com `minAvailable` adequado ao número de réplicas
- [ ] Imagem com tag específica (não apenas `:latest` em produção)
- [ ] Nenhum segredo hardcoded (usar Secrets ou variáveis de ambiente injetadas)

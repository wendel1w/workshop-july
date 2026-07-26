# Rule: Dockerfile Production-Ready

**Escopo:** geração de Dockerfiles para qualquer aplicação deste repositório.
**Objetivo:** produzir imagens otimizadas, seguras e prontas para produção.

## 1. Princípios Obrigatórios

Todo Dockerfile gerado DEVE seguir estes princípios, sem exceção:

- **Multi-stage build:** separar build (SDK/compilação) de runtime (imagem mínima).
- **Imagens Alpine:** usar variantes `-alpine` sempre que disponíveis para a linguagem.
- **Rootless:** executar o processo da aplicação como usuário não-root.
- **Healthcheck:** incluir instrução `HEALTHCHECK` nativa do Docker.
- **Menor superfície possível:** não instalar pacotes desnecessários na imagem final.
- **Layer caching otimizado:** copiar dependências antes do código fonte.
- **Reprodutibilidade:** fixar versões de imagem base com major.minor (ex.: `8.0-alpine`, `22-alpine`).
- **Plataforma explícita:** usar `--platform=linux/amd64` quando aplicável.

## 2. Estrutura Padrão de Stages

```dockerfile
# ========== STAGE 1: BUILD ==========
FROM <sdk-image>:<version>-alpine AS builder
WORKDIR /src
# 1. Copiar manifesto de dependencias (cache de layer)
COPY <manifesto-dependencias> .
# 2. Restaurar/instalar dependencias
RUN <comando-restore>
# 3. Copiar codigo fonte
COPY . .
# 4. Compilar/empacotar
RUN <comando-build>

# ========== STAGE 2: RUNTIME ==========
FROM <runtime-image>:<version>-alpine AS runner
WORKDIR /app

# Variaveis de ambiente
ENV <CHAVE>=<valor>

# Criar usuario nao-root
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser

# Copiar artefatos do builder
COPY --from=builder <path-artefatos> .

# Trocar para usuario nao-root
USER appuser

# Expor porta
EXPOSE <porta>

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD <comando-healthcheck>

# Entrypoint
ENTRYPOINT [<comando-start>]
```

## 3. Regras por Linguagem

### 3.1 .NET (C# / ASP.NET Core)

| Aspecto | Valor |
|---|---|
| Imagem build | `mcr.microsoft.com/dotnet/sdk:<version>-alpine` |
| Imagem runtime | `mcr.microsoft.com/dotnet/aspnet:<version>-alpine` |
| Manifesto | `*.csproj` (ou `*.sln` se multi-projeto) |
| Restore | `dotnet restore` |
| Build | `dotnet publish -c Release -o /app/publish --no-restore` |
| Porta | 8080 (variável `ASPNETCORE_URLS=http://+:8080`) |
| Entrypoint | `["dotnet", "<NomeProjeto>.dll"]` |
| Healthcheck | `wget --no-verbose --tries=1 --spider http://localhost:<porta>/<path>/health \|\| exit 1` |
| Variáveis extras | `DOTNET_RUNNING_IN_CONTAINER=true` |

**Notas .NET:**
- Usar `wget` no healthcheck (disponível no Alpine) em vez de `curl` (não instalado por padrão no aspnet-alpine).
- Se a app expõe healthcheck em subpath (ex.: `/backend/health`), incluir o subpath completo.
- Para .NET 8+, a imagem `aspnet:8.0-alpine` já suporta globalization-invariant por padrão.

### 3.2 Node.js (Next.js / Express / NestJS)

| Aspecto | Valor |
|---|---|
| Imagem build | `node:<version>-alpine` |
| Imagem runtime | `node:<version>-alpine` (mesma, mas sem devDependencies) |
| Manifesto | `package.json` + `package-lock.json` (ou `yarn.lock` / `pnpm-lock.yaml`) |
| Restore | `npm ci --only=production` (ou `npm ci` no build, `npm ci --omit=dev` no runtime) |
| Build | `npm run build` |
| Porta | 3000 (Next.js padrão) |
| Entrypoint (Next.js) | `["node", "server.js"]` (com `output: "standalone"` no next.config) |
| Entrypoint (Express/Nest) | `["node", "dist/main.js"]` |
| Healthcheck | `wget --no-verbose --tries=1 --spider http://localhost:<porta>/health \|\| exit 1` |

**Notas Next.js:**
- Requer `output: "standalone"` no `next.config.mjs` para build otimizado.
- Copiar `public/` e `.next/static` separadamente para o runner.
- Stage intermediário `deps` pode ser usado para separar instalação de dependências.

### 3.3 Python (FastAPI / Flask / Django)

| Aspecto | Valor |
|---|---|
| Imagem build | `python:<version>-alpine` |
| Imagem runtime | `python:<version>-alpine` |
| Manifesto | `requirements.txt` (ou `pyproject.toml` + `poetry.lock`) |
| Restore | `pip install --no-cache-dir --prefix=/install -r requirements.txt` |
| Build | N/A (interpretado) ou `poetry build` |
| Porta | 8000 (uvicorn/gunicorn padrão) |
| Entrypoint (FastAPI) | `["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` |
| Healthcheck | `wget --no-verbose --tries=1 --spider http://localhost:<porta>/health \|\| exit 1` |

**Notas Python:**
- Usar `--prefix=/install` no pip e `COPY --from=builder /install /usr/local` para evitar carregar pip/setuptools no runtime.
- Instalar dependências de compilação (gcc, musl-dev) apenas no stage de build.
- Definir `PYTHONDONTWRITEBYTECODE=1` e `PYTHONUNBUFFERED=1`.

### 3.4 Go

| Aspecto | Valor |
|---|---|
| Imagem build | `golang:<version>-alpine` |
| Imagem runtime | `alpine:<version>` (binário estático) ou `scratch` |
| Manifesto | `go.mod` + `go.sum` |
| Restore | `go mod download` |
| Build | `CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server .` |
| Porta | 8080 (configurável) |
| Entrypoint | `["/app/server"]` |
| Healthcheck | `wget --no-verbose --tries=1 --spider http://localhost:<porta>/health \|\| exit 1` |

**Notas Go:**
- Binário estático permite usar `scratch` ou `alpine` sem dependências de runtime.
- Se usar `scratch`, healthcheck nativo não funciona (sem shell) — usar healthcheck do orchestrator (Kubernetes liveness probe).
- Preferir `alpine` quando healthcheck Docker nativo for necessário.

### 3.5 Java (Spring Boot / Quarkus)

| Aspecto | Valor |
|---|---|
| Imagem build | `maven:<version>-amazoncorretto-<jdk>-alpine` ou `gradle:<version>-jdk<version>-alpine` |
| Imagem runtime | `amazoncorretto:<version>-alpine` ou `eclipse-temurin:<version>-jre-alpine` |
| Manifesto | `pom.xml` (Maven) ou `build.gradle` (Gradle) |
| Restore | `mvn dependency:go-offline` ou `gradle dependencies` |
| Build | `mvn package -DskipTests` ou `gradle build -x test` |
| Porta | 8080 (Spring Boot padrão) |
| Entrypoint | `["java", "-jar", "app.jar"]` |
| Healthcheck | `wget --no-verbose --tries=1 --spider http://localhost:<porta>/actuator/health \|\| exit 1` |

**Notas Java:**
- Para Spring Boot, ativar `spring-boot-starter-actuator` para `/actuator/health`.
- Usar JRE (não JDK) no runtime.
- Considerar `jlink` para criar JRE customizado ainda menor.

## 4. Regras de Segurança (Rootless)

- **NUNCA** executar o processo como `root` na imagem final.
- Criar usuário/grupo com IDs fixos (UID=1001, GID=1001) para compatibilidade com Kubernetes `runAsNonRoot`.
- Se a aplicação precisar escrever em disco (logs, cache), criar o diretório com permissões adequadas ANTES do `USER`:
  ```dockerfile
  RUN mkdir -p /app/tmp && chown appuser:appgroup /app/tmp
  ```
- Não usar portas abaixo de 1024 (requerem privilégio root). Usar 8080, 3000, 8000, etc.
- Não instalar `sudo`, `su` ou ferramentas de escalação de privilégio.

## 5. Regras de Healthcheck

- **Obrigatório** em todo Dockerfile gerado.
- Usar `wget --no-verbose --tries=1 --spider` (disponível em todas as imagens Alpine sem instalação extra).
- **Sempre usar `127.0.0.1` em vez de `localhost`** no endpoint do healthcheck — no Alpine, `localhost` pode resolver para `::1` (IPv6) enquanto a aplicação escuta apenas em IPv4, causando falha de conexão.
- Parâmetros padrão: `--interval=30s --timeout=3s --start-period=10s --retries=3`.
- Ajustar `--start-period` para linguagens com cold start lento (Java: 30s, .NET: 10s, Node/Go/Python: 5s).
- O endpoint de healthcheck DEVE ser implementado pela aplicação. Se não existir, instruir o desenvolvedor a adicioná-lo.

## 6. Regras de Otimização de Camadas

1. Copiar **apenas** o manifesto de dependências primeiro (cache layer de restore).
2. Executar restore/install de dependências (layer pesada, muda pouco).
3. Copiar código fonte (muda sempre, invalida apenas layers abaixo).
4. Compilar/empacotar.
5. Na imagem final, copiar apenas os artefatos necessários — nunca o código fonte, SDKs ou ferramentas de build.

## 7. .dockerignore Obrigatório

Todo projeto DEVE ter um `.dockerignore` com pelo menos:

```
.git
.gitignore
*.md
.env*
.vscode
.idea
node_modules
bin
obj
__pycache__
.pytest_cache
target
dist
.next
```

## 8. Procedimento de Validação

Após gerar o Dockerfile, executar:

```bash
# 1. Build da imagem
docker build -t <nome-app>:test .

# 2. Executar o container em background
docker run -d --name <nome-app>-test -p <porta>:<porta> <nome-app>:test

# 3. Aguardar o start-period do healthcheck
sleep 15

# 4. Verificar o healthcheck
docker inspect --format='{{.State.Health.Status}}' <nome-app>-test

# 5. Testar manualmente o endpoint de health
curl -f http://localhost:<porta>/<path>/health

# 6. Verificar que roda como non-root
docker exec <nome-app>-test whoami
# Deve retornar: appuser

# 7. Cleanup
docker stop <nome-app>-test && docker rm <nome-app>-test
```

**Critérios de aceite:**
- Healthcheck status = `healthy`
- curl retorna HTTP 200
- whoami retorna `appuser` (não `root`)
- Imagem final < 200MB (para linguagens compiladas) ou < 500MB (para JVM)

## 9. Checklist de Revisão

Antes de considerar o Dockerfile pronto, validar:

- [ ] Multi-stage build (ao menos 2 stages: builder + runner)
- [ ] Imagem base Alpine (ou scratch para Go)
- [ ] Versão da imagem base fixada (major.minor)
- [ ] Layer de dependências separada do código fonte
- [ ] Usuário non-root criado e ativo (`USER appuser`)
- [ ] UID/GID fixos (1001:1001)
- [ ] Porta > 1024 exposta
- [ ] `HEALTHCHECK` presente com parâmetros adequados
- [ ] Endpoint de health implementado na aplicação
- [ ] `.dockerignore` presente e adequado
- [ ] Sem segredos, tokens ou credenciais no Dockerfile
- [ ] Sem pacotes desnecessários na imagem final
- [ ] `ENTRYPOINT` em exec form (array, não string)

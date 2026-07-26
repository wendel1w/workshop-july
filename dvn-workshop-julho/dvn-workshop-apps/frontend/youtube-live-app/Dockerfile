# ========== STAGE 1: DEPENDENCIES ==========
FROM --platform=linux/amd64 node:22-alpine AS deps
WORKDIR /app

# 1. Copiar manifestos de dependencias (cache de layer)
COPY package.json package-lock.json ./

# 2. Instalar dependencias (ci = clean install, reprodutivel)
RUN npm ci

# ========== STAGE 2: BUILD ==========
FROM --platform=linux/amd64 node:22-alpine AS builder
WORKDIR /app

# Copiar node_modules do stage anterior
COPY --from=deps /app/node_modules ./node_modules

# Copiar codigo fonte
COPY . .

# Build do Next.js com output standalone
RUN npm run build

# ========== STAGE 3: RUNTIME ==========
FROM --platform=linux/amd64 node:22-alpine AS runner
WORKDIR /app

# Variaveis de ambiente
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOSTNAME="0.0.0.0"
ENV PORT=3000

# Criar usuario nao-root com IDs fixos
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser

# Copiar artefatos estaticos e standalone do builder
COPY --from=builder /app/public ./public
COPY --from=builder --chown=appuser:appgroup /app/.next/standalone ./
COPY --from=builder --chown=appuser:appgroup /app/.next/static ./.next/static

# Trocar para usuario nao-root
USER appuser

# Expor porta
EXPOSE 3000

# Healthcheck (start-period 5s para Node.js conforme skill §5)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/health || exit 1

# Entrypoint em exec form
ENTRYPOINT ["node", "server.js"]

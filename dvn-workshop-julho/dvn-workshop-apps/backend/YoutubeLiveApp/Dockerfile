# ========== STAGE 1: BUILD ==========
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder
WORKDIR /src

# 1. Copiar manifesto de dependencias (cache de layer)
COPY *.csproj ./

# 2. Restaurar dependencias
RUN dotnet restore

# 3. Copiar codigo fonte
COPY . .

# 4. Compilar e publicar
RUN dotnet publish -c Release -o /app/publish --no-restore

# ========== STAGE 2: RUNTIME ==========
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runner
WORKDIR /app

# Variaveis de ambiente
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true

# Criar usuario nao-root com IDs fixos
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser

# Copiar artefatos do builder
COPY --from=builder /app/publish .

# Trocar para usuario nao-root
USER appuser

# Expor porta
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/backend/health || exit 1

# Entrypoint em exec form
ENTRYPOINT ["dotnet", "YoutubeLiveApp.dll"]

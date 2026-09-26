#!/usr/bin/env bash
# =============================================================================
# Taz.SaaS — 02 Backend Services (Vault → servisler → Agent → Gateway)
# Önkoşul: 01-infra.sh (taz-saas-internal network'ü ve altyapı ayakta olmalı)
#
# Kullanım: ./02-services.sh [up|down|pull|ps|logs]   (varsayılan: up)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

PROJECT="taz-apps"
COMPOSE_FILE="docker-compose.apps.yml"
ENV_FILES=(.env .env.services)
ACTION="${1:-up}"

# Başlatma sırası: vault → SERVICES → agent → gateway
SERVICES=(identity payment content bcm llmgateway prompt knowledge toolregistry
          conversation analytics connector connector-worker webscraping business
          workflow guardrail embedding slm speech)
VAULT_WAIT_SECONDS=120

# ── Engine seçimi ────────────────────────────────────────────
echo "Container engine seçin:"
echo "  1) docker"
echo "  2) podman"
read -rp "Seçim [1/2]: " choice
case "$choice" in
  1|docker) ENGINE="docker"; COMPOSE=(docker compose) ;;
  2|podman) ENGINE="podman"; COMPOSE=(podman-compose) ;;
  *) echo "Geçersiz seçim: $choice"; exit 1 ;;
esac
command -v "$ENGINE" >/dev/null || { echo "$ENGINE bulunamadı"; exit 1; }
[ "$ENGINE" = "podman" ] && { command -v podman-compose >/dev/null || { echo "podman-compose bulunamadı"; exit 1; }; }

# ── Ön kontroller ────────────────────────────────────────────
for f in "${ENV_FILES[@]}" .env.vault.sync "$COMPOSE_FILE"; do
  [ -f "$f" ] || { echo "Eksik dosya: $f"; exit 1; }
done
"$ENGINE" network inspect taz-saas-internal >/dev/null 2>&1 \
  || { echo "taz-saas-internal network'ü yok — önce ./01-infra.sh çalıştırın"; exit 1; }
for d in models/guardrail models/slm models/embedding models/whisper-small models/piper; do
  [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ] || echo "UYARI: $d boş/eksik — ilgili servis model yükleyemez"
done
# .NET 8+ image'ları root olmayan "app" kullanıcısıyla (uid 1654) çalışır; host'ta
# bizim kullanıcımızla oluşan dizine yazamaz → Vault "SQLite Error 14: unable to
# open database file" ile düşer. (Taskfile deploy-local ile aynı yaklaşım.)
mkdir -p .data/vault .data/toolregistry-keys
chmod 777 .data/vault .data/toolregistry-keys

ENV_ARGS=()
for f in "${ENV_FILES[@]}"; do ENV_ARGS+=(--env-file "$f"); done
compose() { "${COMPOSE[@]}" -p "$PROJECT" "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" "$@"; }

wait_vault_healthy() {
  echo "Vault healthy bekleniyor (en fazla ${VAULT_WAIT_SECONDS}s)..."
  local waited=0 status
  while [ "$waited" -lt "$VAULT_WAIT_SECONDS" ]; do
    status="$("$ENGINE" ps --filter "name=vault-service" --format '{{.Status}}' | head -1)"
    case "$status" in
      *"(healthy)"*) echo "Vault healthy."; return 0 ;;
    esac
    sleep 3; waited=$((waited + 3))
  done
  echo "Vault ${VAULT_WAIT_SECONDS}s içinde healthy olmadı. Son durum: ${status:-yok}"
  echo "Loglar: $ENGINE logs \$($ENGINE ps -q --filter name=vault-service)"
  exit 1
}

# ── Aksiyon ──────────────────────────────────────────────────
case "$ACTION" in
  up)
    compose pull
    compose up -d vault-service
    wait_vault_healthy
    compose up -d "${SERVICES[@]}"
    compose up -d agent
    compose up -d gateway
    compose ps
    ;;
  down) compose down ;;
  pull) compose pull ;;
  ps)   compose ps ;;
  logs) compose logs -f --tail=100 ;;
  *) echo "Bilinmeyen aksiyon: $ACTION (up|down|pull|ps|logs)"; exit 1 ;;
esac

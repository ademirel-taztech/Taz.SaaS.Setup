#!/usr/bin/env bash
# =============================================================================
# Taz.SaaS — 03 Web Apps (web, app, admin, taz-landing, widget)
# Önkoşul: 01-infra.sh (taz-saas-internal network'ü), 02-services.sh (API)
#
# Kullanım: ./03-webapps.sh [up|down|pull|ps|logs]   (varsayılan: up)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

PROJECT="taz-webui"
COMPOSE_FILE="docker-compose.webui.yml"
ENV_FILES=(.env .env.web)
ACTION="${1:-up}"

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
for f in "${ENV_FILES[@]}" "$COMPOSE_FILE"; do
  [ -f "$f" ] || { echo "Eksik dosya: $f"; exit 1; }
done
"$ENGINE" network inspect taz-saas-internal >/dev/null 2>&1 \
  || { echo "taz-saas-internal network'ü yok — önce ./01-infra.sh çalıştırın"; exit 1; }

ENV_ARGS=()
for f in "${ENV_FILES[@]}"; do ENV_ARGS+=(--env-file "$f"); done
compose() { "${COMPOSE[@]}" -p "$PROJECT" "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" "$@"; }

# ── Aksiyon ──────────────────────────────────────────────────
case "$ACTION" in
  up)
    compose pull
    compose up -d
    compose ps
    ;;
  down) compose down ;;
  pull) compose pull ;;
  ps)   compose ps ;;
  logs) compose logs -f --tail=100 ;;
  *) echo "Bilinmeyen aksiyon: $ACTION (up|down|pull|ps|logs)"; exit 1 ;;
esac

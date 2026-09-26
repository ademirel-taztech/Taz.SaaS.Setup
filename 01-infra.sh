#!/usr/bin/env bash
# =============================================================================
# Taz.SaaS — 01 Infrastructure (PostgreSQL, Redis, RabbitMQ, MinIO, Seq, Chrome)
# taz-saas-internal network'ünü oluşturur — 02 ve 03'ten önce çalıştırılmalı.
#
# Kullanım: ./01-infra.sh [up|down|pull|ps|logs]   (varsayılan: up)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

PROJECT="taz-infra"
COMPOSE_FILE="docker-compose.infra.yml"
ENV_FILES=(.env .env.infra)
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
# Dosya eksikken bir kez `up` yapıldıysa podman bind-mount için aynı isimde
# BOŞ DİZİN oluşturur; ls'de "var" görünür ama dosya değildir (postgres 126 ile çıkar).
INIT_SCRIPT="scripts/init-postgres.sh"
if [ -d "$INIT_SCRIPT" ]; then
  echo "$INIT_SCRIPT bir DİZİN (dosya değil) — önceki bir mount denemesinde oluşmuş."
  echo "Düzeltme: rm -rf $INIT_SCRIPT  ve dosyayı yeniden kopyalayın."
  exit 1
fi
for f in "${ENV_FILES[@]}" "$COMPOSE_FILE" "$INIT_SCRIPT"; do
  [ -f "$f" ] || { echo "Eksik dosya: $PWD/$f"; exit 1; }
done
chmod +x "$INIT_SCRIPT"

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

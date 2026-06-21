#!/usr/bin/env bash
# s3-testbed.sh — stand up a local MinIO (S3-compatible) sink for the VSL S3
# round-trip matrix (tests/VSLS3E2ETST.m), reachable BY NAME from both the YDB
# and IRIS test engines.
#
# VENDORED from m-stdlib/scripts/s3-testbed.sh (kept byte-compatible) so the
# Option-A round-trip gate (`make test-s3-matrix`) is self-contained — CI does
# not check out the sibling m-stdlib. Keep the two copies in sync; the network
# name / MinIO host / bucket / creds are the same throwaway local fixtures the
# VSLS3E2ETST cfg() hardcodes.
#
# The engines run inside docker, so MinIO joins a dedicated user-defined network
# (S3_NET) that both engines are also connected to; on that network the engines
# resolve the sink as "$MINIO_HOST:9000" (path-style endpoint, no code change —
# the STDS3/STDSIGV4 endpoint override, S3 design §10 / D-S3-2).
#
# Usage:
#   scripts/s3-testbed.sh up        # network + MinIO + bucket; connect engines
#   scripts/s3-testbed.sh down      # remove MinIO + network; disconnect engines
#   scripts/s3-testbed.sh status    # show what is running
#
# Credentials/bucket are throwaway local fixtures, intentionally hardcoded and
# mirrored in tests/VSLS3E2ETST.m. Nothing here ever touches production AWS.
# NOTE: this orchestrates MinIO only (docker run/network/inspect) — it never
# execs into an engine container, so it honors the m/v waterline transport
# monopoly (engine work goes through `m test --docker`, never a raw exec).
set -euo pipefail

S3_NET="${S3_NET:-m-s3-test}"
MINIO_HOST="${MINIO_HOST:-m-s3-minio}"
MINIO_IMAGE="${MINIO_IMAGE:-minio/minio:RELEASE.2024-10-13T13-34-11Z}"
MINIO_USER="${MINIO_USER:-minioadmin}"
MINIO_PASS="${MINIO_PASS:-minioadmin}"
BUCKET="${BUCKET:-vista-test-logs}"
DATA_DIR="${DATA_DIR:-$HOME/data/m-s3-minio/data}"
ENGINES=("${ENGINE_YDB:-m-test-engine}" "${ENGINE_IRIS:-m-test-iris}")

log() { printf '  %s\n' "$*"; }

connect_engines() {
  for e in "${ENGINES[@]}"; do
    if docker inspect "$e" >/dev/null 2>&1; then
      if ! docker inspect "$e" --format '{{json .NetworkSettings.Networks}}' | grep -q "\"$S3_NET\""; then
        docker network connect "$S3_NET" "$e" && log "connected $e -> $S3_NET"
      else
        log "$e already on $S3_NET"
      fi
    else
      log "engine $e not present (skipped)"
    fi
  done
}

disconnect_engines() {
  for e in "${ENGINES[@]}"; do
    if docker inspect "$e" >/dev/null 2>&1 \
      && docker inspect "$e" --format '{{json .NetworkSettings.Networks}}' | grep -q "\"$S3_NET\""; then
      docker network disconnect "$S3_NET" "$e" 2>/dev/null && log "disconnected $e from $S3_NET" || true
    fi
  done
}

up() {
  docker network inspect "$S3_NET" >/dev/null 2>&1 || { docker network create "$S3_NET" >/dev/null && log "created network $S3_NET"; }
  # Pre-create the bucket as a directory under the data dir (single-node MinIO
  # treats a top-level dir as a bucket — no mc client needed).
  mkdir -p "$DATA_DIR/$BUCKET"
  if ! docker inspect "$MINIO_HOST" >/dev/null 2>&1; then
    docker run -d --name "$MINIO_HOST" --network "$S3_NET" \
      -p 9000:9000 -p 9001:9001 \
      -e "MINIO_ROOT_USER=$MINIO_USER" -e "MINIO_ROOT_PASSWORD=$MINIO_PASS" \
      -v "$DATA_DIR:/data" \
      "$MINIO_IMAGE" server /data --console-address ":9001" >/dev/null
    log "started MinIO container $MINIO_HOST (bucket: $BUCKET)"
  else
    docker start "$MINIO_HOST" >/dev/null 2>&1 || true
    log "MinIO container $MINIO_HOST already exists"
  fi
  connect_engines
  # Wait for readiness (live endpoint).
  for _ in $(seq 1 30); do
    if curl -sf "http://localhost:9000/minio/health/live" >/dev/null 2>&1; then
      log "MinIO healthy at http://localhost:9000 (engine endpoint: http://$MINIO_HOST:9000)"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: MinIO did not become healthy" >&2
  exit 1
}

down() {
  disconnect_engines
  docker rm -f "$MINIO_HOST" >/dev/null 2>&1 && log "removed MinIO container $MINIO_HOST" || true
  docker network rm "$S3_NET" >/dev/null 2>&1 && log "removed network $S3_NET" || true
}

status() {
  echo "network:"; docker network inspect "$S3_NET" --format '  {{.Name}} ({{len .Containers}} containers)' 2>/dev/null || echo "  (absent)"
  echo "minio:";   docker ps --filter "name=$MINIO_HOST" --format '  {{.Names}}\t{{.Status}}' || true
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *) echo "usage: $0 {up|down|status}" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
set -Eeuo pipefail

# Qwen Image Edit 2511 FP8 bundle; downloads only, no Python package changes.
# Usage:
#   MODEL_ROOT=/workspace/models ./install_qwen_fp8.sh
#   MODEL_ROOT=/workspace/models ./install_qwen_fp8.sh check

log()  { printf '\n[QWEN-2511] %s\n' "$*"; }
warn() { printf '\n[QWEN-2511] WARNUNG: %s\n' "$*" >&2; }
die()  { printf '\n[QWEN-2511] FEHLER: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

COMFY="${COMFY:-/workspace/ComfyUI}"
MODEL_ROOT="${MODEL_ROOT:-$COMFY/models}"
MODE="${1:-download}"

[[ "$MODEL_ROOT" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "MODEL_ROOT muss ein absoluter Pfad ohne Leerzeichen sein: $MODEL_ROOT"
have sha256sum || die 'sha256sum fehlt.'
[[ "$MODE" == download || "$MODE" == check ]] || die "Aufruf: $0 [download|check]"

mkdir -p \
  "$MODEL_ROOT/loras" \
  "$MODEL_ROOT/vae" \
  "$MODEL_ROOT/text_encoders" \
  "$MODEL_ROOT/diffusion_models"

# name|subdirectory|size_bytes|sha256|URL
MODELS=(
  'Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors|loras|850000000|22226e8d05d354bb356627d428809f5afd7819399b077238a2b70a82883a904f|https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors?download=true'
  'qwen_image_vae.safetensors|vae|254000000|a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors?download=true'
  'qwen_2.5_vl_7b_fp8_scaled.safetensors|text_encoders|9380000000|cb5636d852a0ea6a9075ab1bef496c0db7aef13c02350571e388aea959c5c0b4|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors?download=true'
  'qwen_image_edit_2511_fp8mixed.safetensors|diffusion_models|20500000000|c9fdc158e46d3b61ef75f21ae866ca2fe808bf4a53643120d1c1e87c19280a4e|https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors?download=true'
)

parse_model() {
  local record="$1"
  IFS='|' read -r NAME SUBDIR SIZE SHA URL <<< "$record"
  DEST="$MODEL_ROOT/$SUBDIR/$NAME"
  TMP="$DEST.part"
}

verify_file() {
  local path="$1" sha="$2"
  [[ -f "$path" ]] || return 1
  echo "$sha  $path" | sha256sum --check --status -
}

check_models() {
  local missing=0
  log "Prüfe Qwen Image Edit 2511 Material in $MODEL_ROOT"
  for record in "${MODELS[@]}"; do
    parse_model "$record"
    if verify_file "$DEST" "$SHA"; then
      printf 'OK       %s/%s\n' "$SUBDIR" "$NAME"
    elif [[ -f "$DEST" ]]; then
      printf 'CHECKSUM %s/%s\n' "$SUBDIR" "$NAME"
      missing=1
    else
      printf 'FEHLT    %s/%s\n' "$SUBDIR" "$NAME"
      missing=1
    fi
  done
  return "$missing"
}

download_one() {
  parse_model "$1"
  if verify_file "$DEST" "$SHA"; then
    log "Bereits vorhanden und geprüft: $SUBDIR/$NAME"
    return
  fi
  [[ ! -f "$DEST" ]] || warn "Prüfsumme stimmt nicht; Datei wird neu geladen: $DEST"

  free_bytes="$(df -PB1 "$MODEL_ROOT" | awk 'NR==2 {print $4}')"
  partial_bytes=0
  [[ ! -f "$TMP" ]] || partial_bytes="$(stat -c %s "$TMP")"
  required_bytes=$(( SIZE - partial_bytes + 1073741824 ))
  (( required_bytes > 1073741824 )) || required_bytes=1073741824
  (( free_bytes >= required_bytes )) || die "Nicht genug Speicher für $NAME"
  log "Download: $SUBDIR/$NAME"
  if have aria2c; then
    aria2c \
      --continue=true \
      --allow-overwrite=true \
      --auto-file-renaming=false \
      --file-allocation=none \
      --max-connection-per-server=8 \
      --split=8 \
      --min-split-size=32M \
      --summary-interval=15 \
      --dir="$(dirname "$TMP")" \
      --out="$(basename "$TMP")" \
      "$URL"
  elif have curl; then
    curl -fL --retry 8 --retry-all-errors --connect-timeout 20 \
      --continue-at - "$URL" -o "$TMP"
  else
    die 'aria2c oder curl muss installiert sein.'
  fi

  if ! verify_file "$TMP" "$SHA"; then
    mv -- "$TMP" "$TMP.bad.$(date +%s).$$"
    die "SHA-256 falsch: $NAME. Fehlerhafte Datei beiseite gelegt; erneut starten."
  fi
  mv -f -- "$TMP" "$DEST"
  chmod 0644 "$DEST"
  log "Gespeichert und geprüft: $DEST"
}

if [[ "$MODE" == check ]]; then
  check_models
  exit $?
fi

log 'Qwen Image Edit 2511 Material: 4 Dateien, ca. 31 GB'
for record in "${MODELS[@]}"; do download_one "$record"; done
check_models
log 'Alle vier Dateien sind vorhanden und SHA-256-geprüft.'

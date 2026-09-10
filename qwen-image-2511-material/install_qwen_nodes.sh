#!/usr/bin/env bash
set -Eeuo pipefail
# Qwen custom nodes only. No model weights.
# Run with the ComfyUI Python environment active (Vast: /venv/main).
COMFY="${COMFY:-/workspace/ComfyUI}"
if [[ -f /venv/main/bin/activate ]]; then source /venv/main/bin/activate; fi
PYTHON="${PYTHON:-python}"
NODE="$COMFY/custom_nodes/ComfyUI-QwenVL"
REPO="${QWENVL_NODE_REPO:-https://github.com/huchukato/ComfyUI-QwenVL-Mod.git}"
[[ -f "$COMFY/main.py" ]] || { echo "ComfyUI fehlt: $COMFY"; exit 1; }
command -v git >/dev/null
"$PYTHON" -c 'import torch; print("Torch:", torch.__version__, "CUDA:", torch.version.cuda)'
mkdir -p "$COMFY/setup_manifests" "$COMFY/custom_nodes"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
LOG="$COMFY/setup_manifests/qwen-nodes-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "Abbruch. Log: $LOG."; exit 1' ERR
"$PYTHON" -m pip freeze > "$COMFY/setup_manifests/pip-nodes-before-$STAMP.txt"
CONSTRAINTS="$COMFY/setup_manifests/torch-$STAMP.txt"
"$PYTHON" - <<'PY' > "$CONSTRAINTS"
from importlib.metadata import version, PackageNotFoundError
for p in ("torch", "torchvision", "torchaudio"):
    try: print(f"{p}=={version(p)}")
    except PackageNotFoundError: pass
PY
ORIGIN="$(git -C "$NODE" remote get-url origin 2>/dev/null || true)"
if [[ "$ORIGIN" != "$REPO" && "$ORIGIN" != "${REPO%.git}" ]]; then
    STAGE="$COMFY/setup_manifests/qwenvl-node-$STAMP"
    git clone "$REPO" "$STAGE"
    if [[ -e "$NODE" || -L "$NODE" ]]; then
        mkdir -p "$COMFY/custom_nodes_backup"
        mv -- "$NODE" "$COMFY/custom_nodes_backup/ComfyUI-QwenVL.bak-$STAMP"
    fi
    mv -- "$STAGE" "$NODE"
fi
if [[ -n "${QWENVL_REF:-}" ]]; then
    [[ -z "$(git -C "$NODE" status --porcelain)" ]] || { echo "Lokale Node-Aenderungen"; exit 1; }
    git -C "$NODE" fetch origin --tags
    git -C "$NODE" checkout --detach "$QWENVL_REF"
fi
git -C "$NODE" rev-parse HEAD > "$COMFY/setup_manifests/node-$STAMP.txt"
REQS=()
[[ -f "$NODE/requirements.txt" ]] && REQS+=(-r "$NODE/requirements.txt")
"$PYTHON" -m pip install -c "$CONSTRAINTS" "${REQS[@]}" 'transformers>=4.57.0' huggingface_hub hf_xet
"$PYTHON" -m pip check
"$PYTHON" -m pip freeze > "$COMFY/setup_manifests/pip-nodes-after-$STAMP.txt"
echo "Node: $NODE"
echo "Repo: $REPO"
echo "HEAD: $(git -C "$NODE" rev-parse HEAD)"
echo "Qwen Image Edit 2511 sitzt in ComfyUI-Core. Kein Extra-Node."
echo "Gewichte separat: bash qwen-image-2511-material/install_qwenvl_mod_8b.sh"
echo "Danach ComfyUI neu starten. Node: Qwen3-VL-8B-Instruct."

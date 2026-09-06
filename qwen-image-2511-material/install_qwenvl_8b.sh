#!/usr/bin/env bash
set -Eeuo pipefail
# Run with the ComfyUI Python environment active (Vast: /venv/main).
COMFY="${COMFY:-/workspace/ComfyUI}"
PYTHON="${PYTHON:-python}"
NODE="$COMFY/custom_nodes/ComfyUI-QwenVL"
MODEL="$COMFY/models/LLM/Qwen-VL/Qwen3-VL-8B-Instruct"
[[ -f "$COMFY/main.py" ]] || { echo "ComfyUI fehlt: $COMFY"; exit 1; }
command -v git >/dev/null
"$PYTHON" -c 'import torch; print("Torch:", torch.__version__, "CUDA:", torch.version.cuda)'
mkdir -p "$COMFY/setup_manifests" "$COMFY/custom_nodes" "$MODEL"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
LOG="$COMFY/setup_manifests/qwenvl-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "Abbruch. Log: $LOG. Downloads bleiben erhalten."; exit 1' ERR
"$PYTHON" -m pip freeze > "$COMFY/setup_manifests/pip-before-$STAMP.txt"
CONSTRAINTS="$COMFY/setup_manifests/torch-$STAMP.txt"
"$PYTHON" - <<'PY' > "$CONSTRAINTS"
from importlib.metadata import version, PackageNotFoundError
for p in ("torch", "torchvision", "torchaudio"):
    try: print(f"{p}=={version(p)}")
    except PackageNotFoundError: pass
PY
if [[ ! -d "$NODE/.git" ]]; then
    [[ ! -e "$NODE" ]] || { echo "Ziel existiert ohne Git: $NODE"; exit 1; }
    git clone https://github.com/1038lab/ComfyUI-QwenVL.git "$NODE"
fi
if [[ -n "${QWENVL_REF:-}" ]]; then
    [[ -z "$(git -C "$NODE" status --porcelain)" ]] || { echo "Lokale Node-Aenderungen"; exit 1; }
    git -C "$NODE" fetch origin --tags
    git -C "$NODE" checkout --detach "$QWENVL_REF"
fi
git -C "$NODE" rev-parse HEAD > "$COMFY/setup_manifests/node-$STAMP.txt"
# Existing checkout is retained; no automatic pull.
"$PYTHON" -m pip install -c "$CONSTRAINTS" -r "$NODE/requirements.txt" 'transformers>=4.57.0' huggingface_hub hf_xet
export HF_HOME="$COMFY/.cache/huggingface"
export HF_HUB_DOWNLOAD_TIMEOUT=120
unset HF_HUB_ENABLE_HF_TRANSFER
"$PYTHON" - "$MODEL" "$COMFY/setup_manifests/model-$STAMP.txt" <<'PY'
import hashlib, json, os, sys
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor
root = Path(sys.argv[1])
info = HfApi().model_info("Qwen/Qwen3-VL-8B-Instruct", revision=os.getenv("MODEL_REVISION", "main"), files_metadata=True)
Path(sys.argv[2]).write_text(info.sha + "\n")
snapshot_download(repo_id=info.id, revision=info.sha, local_dir=root, max_workers=4)
index = json.loads((root / "model.safetensors.index.json").read_text())
required = {"config.json", "tokenizer.json", "preprocessor_config.json", *index["weight_map"].values()}
for name in required:
    if not (root / name).is_file() or (root / name).stat().st_size == 0:
        raise RuntimeError(f"Modell-Datei fehlt: {name}")
for item in info.siblings:
    if item.rfilename not in required:
        continue
    path = root / item.rfilename
    if item.size is not None and path.stat().st_size != item.size:
        raise RuntimeError(f"Falsche Groesse: {path}")
    if item.lfs and item.lfs.sha256:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
                h.update(chunk)
        if h.hexdigest() != item.lfs.sha256:
            raise RuntimeError(f"SHA-256 falsch: {path}; Datei beiseite verschieben und erneut starten.")
    print("OK", item.rfilename)
print("Modellrevision:", info.sha)
PY
"$PYTHON" -m pip check
"$PYTHON" -m pip freeze > "$COMFY/setup_manifests/pip-after-$STAMP.txt"
echo "Fertig: $MODEL"
echo "ComfyUI neu starten. Im QwenVL-Node Qwen3-VL-8B-Instruct waehlen."
# No inference/GPU generation test is performed by this installer.

#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# QWEN FURNITURE AI STACK FOR COMFYUI / VAST.AI
# Everything lives under /workspace/ComfyUI
# ============================================================

COMFY="${COMFY:-/workspace/ComfyUI}"

MODELS="$COMFY/models"
CUSTOM_NODES="$COMFY/custom_nodes"

DIFFUSION="$MODELS/diffusion_models"
TEXT_ENCODERS="$MODELS/text_encoders"
VAE="$MODELS/vae"
LORAS="$MODELS/loras"

QWENVL_ROOT="$MODELS/LLM/Qwen-VL"
QWENVL_MODEL="$QWENVL_ROOT/Qwen3-VL-8B-Instruct"

HF_HOME="$COMFY/.cache/huggingface"
TMP="$COMFY/.downloads"
LOGDIR="$COMFY/logs"
MANIFESTDIR="$COMFY/setup_manifests"

QWENVL_NODE="$CUSTOM_NODES/ComfyUI-QwenVL"

# Override when you want a fixed Git commit/tag:
# QWENVL_REF=<commit> ./install_qwen_furniture_stack.sh
QWENVL_REF="${QWENVL_REF:-main}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOGFILE="$LOGDIR/install_qwen_${TIMESTAMP}.log"
MANIFEST="$MANIFESTDIR/qwen_stack_${TIMESTAMP}.txt"


# ============================================================
# ERROR HANDLER
# ============================================================

trap '
STATUS=$?
echo
echo "============================================================"
echo " INSTALL FAILED"
echo " Exit code: $STATUS"
echo " Line:      $LINENO"
echo " Log:       '"$LOGFILE"'"
echo
echo "Partial downloads are intentionally kept in:"
echo "  '"$TMP"'"
echo
echo "Run the script again to retry."
echo "============================================================"
exit $STATUS
' ERR


# ============================================================
# VALIDATE COMFYUI
# ============================================================

if [[ ! -d "$COMFY" ]]; then
    echo "ERROR: $COMFY does not exist."
    echo "Use a Vast image/template with ComfyUI already installed."
    exit 1
fi

cd "$COMFY"


# ============================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================

mkdir -p \
    "$DIFFUSION" \
    "$TEXT_ENCODERS" \
    "$VAE" \
    "$LORAS" \
    "$QWENVL_ROOT" \
    "$CUSTOM_NODES" \
    "$HF_HOME" \
    "$TMP" \
    "$LOGDIR" \
    "$MANIFESTDIR"


# ============================================================
# LOG OUTPUT
# ============================================================

exec > >(tee -a "$LOGFILE") 2>&1


# ============================================================
# HUGGING FACE ENVIRONMENT
# ============================================================

export HF_HOME="$HF_HOME"

# Large files can exceed short default network timeouts.
export HF_HUB_DOWNLOAD_TIMEOUT=60

# Old hf_transfer switch is deprecated.
unset HF_HUB_ENABLE_HF_TRANSFER || true

# Do NOT force HF_XET_HIGH_PERFORMANCE.
# Xet defaults are normally sufficient and more conservative.
# Enable manually if wanted:
#
# export HF_XET_HIGH_PERFORMANCE=1

export PIP_DISABLE_PIP_VERSION_CHECK=1


# ============================================================
# PREFLIGHT
# ============================================================

echo
echo "============================================================"
echo " QWEN FURNITURE STACK"
echo "============================================================"
echo

echo "Timestamp:"
date -Is

echo
echo "Working directory:"
pwd

echo
echo "Architecture:"
uname -m

echo
echo "Python:"
python -VV
python -c 'import sys; print(sys.executable)'

echo
echo "System memory:"
free -h || true

echo
echo "Storage:"
df -h "$COMFY"

echo
echo "GPU:"
nvidia-smi || true

echo
echo "PyTorch:"
python - <<'PY'
import torch

print("torch:", torch.__version__)
print("torch CUDA:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
    print("Compute capability:", torch.cuda.get_device_capability(0))
PY


# ============================================================
# STORAGE CHECK
# ============================================================

FREE_KB="$(df -Pk "$COMFY" | awk 'NR==2 {print $4}')"
FREE_GIB=$(( FREE_KB / 1024 / 1024 ))

echo
echo "Approximately ${FREE_GIB} GiB free."

if (( FREE_GIB < 100 )); then
    echo
    echo "WARNING:"
    echo "The complete stack needs roughly 90+ GB."
    echo "100+ GiB free space is recommended."
    echo
fi


# ============================================================
# GIT CHECK
# ============================================================

if ! command -v git >/dev/null 2>&1; then

    if command -v apt-get >/dev/null 2>&1 && [[ "$(id -u)" == "0" ]]; then

        echo
        echo "Installing git..."

        apt-get update
        apt-get install -y git

    else

        echo "ERROR: git is required."
        exit 1

    fi

fi

git --version


# ============================================================
# SAVE PYTHON STATE BEFORE INSTALL
# ============================================================

echo
echo "============================================================"
echo " SAVE PYTHON ENVIRONMENT"
echo "============================================================"

python -m pip freeze > "$MANIFESTDIR/pip_before_${TIMESTAMP}.txt"
python - <<'PY_CONSTRAINTS' > "$MANIFESTDIR/torch_constraints_${TIMESTAMP}.txt"
from importlib.metadata import version, PackageNotFoundError
for package in ("torch", "torchvision", "torchaudio"):
    try:
        print(f"{package}=={version(package)}")
    except PackageNotFoundError:
        pass
PY_CONSTRAINTS
export PIP_CONSTRAINT="$MANIFESTDIR/torch_constraints_${TIMESTAMP}.txt"


# ============================================================
# INSTALL / VERIFY HUGGING FACE CLI
# ============================================================

echo
echo "============================================================"
echo " HUGGING FACE CLI"
echo "============================================================"

if ! python -c "import huggingface_hub, hf_xet" >/dev/null 2>&1 || ! command -v hf >/dev/null 2>&1; then

    echo "Installing huggingface_hub + hf_xet..."

    python -m pip install \
        huggingface_hub \
        hf_xet

fi

hf --version

echo
echo "HF_HOME:"
echo "$HF_HOME"

echo
echo "Authentication:"
hf auth whoami || echo "Not logged in. Public model downloads should still work."


# ============================================================
# CUSTOM NODE
# ============================================================

echo
echo "============================================================"
echo " COMFYUI-QWENVL CUSTOM NODE"
echo "============================================================"

if [[ ! -d "$QWENVL_NODE/.git" ]]; then

    if [[ -e "$QWENVL_NODE" ]]; then
        echo "ERROR:"
        echo "$QWENVL_NODE exists but is not a Git repository."
        exit 1
    fi

    git clone \
        https://github.com/1038lab/ComfyUI-QwenVL.git \
        "$QWENVL_NODE"

fi


# ============================================================
# CHECKOUT REQUESTED VERSION
# ============================================================

cd "$QWENVL_NODE"

if [[ "$QWENVL_REF" != "main" ]]; then

    echo
    echo "Checking out QwenVL ref:"
    echo "$QWENVL_REF"

    [[ -z "$(git status --porcelain)" ]] || { echo "Local node changes: refusing checkout"; exit 1; }
    git fetch origin --tags
    git checkout "$QWENVL_REF"

else

    echo
    echo "Using currently installed QwenVL revision."
    echo "No automatic git pull is performed."

fi

QWENVL_COMMIT="$(git rev-parse HEAD)"

echo
echo "QwenVL commit:"
echo "$QWENVL_COMMIT"


# ============================================================
# QWENVL DEPENDENCIES
# ============================================================

echo
echo "============================================================"
echo " QWENVL PYTHON DEPENDENCIES"
echo "============================================================"

# No -U here.
# Existing working packages such as torch are not deliberately upgraded.
python -m pip install \
    -r "$QWENVL_NODE/requirements.txt"


# ============================================================
# VERIFY TRANSFORMERS
# ============================================================

python - <<'PY'
from packaging.version import Version
import transformers

version = Version(transformers.__version__)

print("Transformers:", version)

if version < Version("4.57.0"):
    raise RuntimeError(
        "Qwen3-VL requires transformers >= 4.57.0"
    )
PY


# ============================================================
# DOWNLOAD HELPER
# ============================================================

cd "$COMFY"

download_file() {

    local repo="$1"
    local remote_path="$2"
    local destination="$3"
    local temp_name="$4"

    echo
    echo "------------------------------------------------------------"
    echo "Repository:"
    echo "  $repo"
    echo
    echo "File:"
    echo "  $remote_path"
    echo
    echo "Destination:"
    echo "  $destination"
    echo "------------------------------------------------------------"

    if [[ -s "$destination" ]]; then

        echo
        echo "Already installed -> SKIP"
        ls -lh "$destination"
        return 0

    fi

    local work="$TMP/$temp_name"

    mkdir -p "$work"

    hf download \
        "$repo" \
        "$remote_path" \
        --local-dir "$work" \
        --max-workers 8

    local downloaded="$work/$remote_path"

    if [[ ! -s "$downloaded" ]]; then
        echo "ERROR: downloaded file not found:"
        echo "$downloaded"
        exit 1
    fi

    mkdir -p "$(dirname "$destination")"

    mv -f \
        "$downloaded" \
        "$destination"

    # Keep download metadata for diagnostics.

    echo
    echo "Installed:"
    ls -lh "$destination"
}


# ============================================================
# 1 / 6
# QWEN IMAGE EDIT 2511 BF16
# ============================================================

echo
echo "============================================================"
echo " 1/6 QWEN IMAGE EDIT 2511 BF16"
echo " FINAL QUALITY"
echo "============================================================"

download_file \
    "Comfy-Org/Qwen-Image-Edit_ComfyUI" \
    "split_files/diffusion_models/qwen_image_edit_2511_bf16.safetensors" \
    "$DIFFUSION/qwen_image_edit_2511_bf16.safetensors" \
    "qwen_edit_bf16"


# ============================================================
# 2 / 6
# QWEN IMAGE EDIT 2511 INT8 CONVROT
# ============================================================

echo
echo "============================================================"
echo " 2/6 QWEN IMAGE EDIT 2511 INT8 CONVROT"
echo " FAST / PREVIEW"
echo "============================================================"

download_file \
    "Comfy-Org/Qwen-Image-Edit_ComfyUI" \
    "split_files/diffusion_models/qwen_image_edit_2511_int8_convrot.safetensors" \
    "$DIFFUSION/qwen_image_edit_2511_int8_convrot.safetensors" \
    "qwen_edit_int8"


# ============================================================
# 3 / 6
# QWEN 2.5 VL 7B FP8 TEXT ENCODER
# ============================================================

echo
echo "============================================================"
echo " 3/6 QWEN 2.5 VL 7B FP8 TEXT ENCODER"
echo "============================================================"

download_file \
    "Comfy-Org/HunyuanVideo_1.5_repackaged" \
    "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$TEXT_ENCODERS/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "qwen_text_encoder"


# ============================================================
# 4 / 6
# QWEN IMAGE VAE
# ============================================================

echo
echo "============================================================"
echo " 4/6 QWEN IMAGE VAE"
echo "============================================================"

download_file \
    "Comfy-Org/Qwen-Image_ComfyUI" \
    "split_files/vae/qwen_image_vae.safetensors" \
    "$VAE/qwen_image_vae.safetensors" \
    "qwen_image_vae"


# ============================================================
# 5 / 6
# QWEN IMAGE EDIT 2511 LIGHTNING 4-STEP
# ============================================================

echo
echo "============================================================"
echo " 5/6 QWEN IMAGE EDIT 2511 LIGHTNING 4-STEP"
echo "============================================================"

download_file \
    "lightx2v/Qwen-Image-Edit-2511-Lightning" \
    "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
    "$LORAS/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
    "qwen_lightning"


# ============================================================
# 6 / 6
# QWEN3-VL-8B-INSTRUCT
# ============================================================

echo
echo "============================================================"
echo " 6/6 QWEN3-VL-8B-INSTRUCT"
echo "============================================================"

# Optional model from the original four-file material bundle.
if [[ "${INCLUDE_FP8MIXED:-0}" == 1 ]]; then
    download_file \
        "Comfy-Org/Qwen-Image-Edit_ComfyUI" \
        "split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
        "$DIFFUSION/qwen_image_edit_2511_fp8mixed.safetensors" \
        "qwen_edit_fp8mixed"
fi

mkdir -p "$QWENVL_MODEL"

# HF resumes interrupted downloads and reuses its local metadata.
hf download "Qwen/Qwen3-VL-8B-Instruct" \
    --local-dir "$QWENVL_MODEL" --max-workers 8

REQUIRED_QWENVL_FILES=(config.json tokenizer.json preprocessor_config.json model.safetensors.index.json)
mapfile -t QWENVL_SHARDS < <(python - "$QWENVL_MODEL/model.safetensors.index.json" <<'PY_SHARDS'
import json, sys
with open(sys.argv[1]) as f:
    index = json.load(f)
for name in sorted(set(index["weight_map"].values())):
    print(name)
PY_SHARDS
)
(( ${#QWENVL_SHARDS[@]} > 0 )) || { echo "No model shards found"; exit 1; }
REQUIRED_QWENVL_FILES+=("${QWENVL_SHARDS[@]}")

echo
du -sh "$QWENVL_MODEL"


# ============================================================
# VERIFY REQUIRED MODEL FILES
# ============================================================

echo
echo "============================================================"
echo " VERIFY MODEL INSTALLATION"
echo "============================================================"

REQUIRED_FILES=(
    "$DIFFUSION/qwen_image_edit_2511_bf16.safetensors"
    "$DIFFUSION/qwen_image_edit_2511_int8_convrot.safetensors"
    "$TEXT_ENCODERS/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "$VAE/qwen_image_vae.safetensors"
    "$LORAS/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
)

for file in "${REQUIRED_FILES[@]}"; do

    if [[ ! -s "$file" ]]; then
        echo "MISSING:"
        echo "$file"
        exit 1
    fi

    ls -lh "$file"

done


# ============================================================
# VERIFY QWEN3-VL AGAIN
# ============================================================

for file in "${REQUIRED_QWENVL_FILES[@]}"; do

    if [[ ! -s "$QWENVL_MODEL/$file" ]]; then
        echo "MISSING Qwen3-VL file:"
        echo "$QWENVL_MODEL/$file"
        exit 1
    fi

done


# ============================================================
# PYTHON CHECK
# ============================================================

echo
echo "============================================================"
echo " PYTHON / CUDA CHECK"
echo "============================================================"

python - <<'PY'
import torch
import transformers
import huggingface_hub

print("torch:", torch.__version__)
print("torch CUDA:", torch.version.cuda)
print("transformers:", transformers.__version__)
print("huggingface_hub:", huggingface_hub.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
    print("Compute capability:", torch.cuda.get_device_capability(0))
PY


# ============================================================
# PIP CONSISTENCY CHECK
# ============================================================

echo
echo "============================================================"
echo " PIP CHECK"
echo "============================================================"

if python -m pip check; then
    echo "pip check: OK"
else
    echo
    echo "WARNING:"
    echo "pip check found dependency conflicts."
    echo "See log:"
    echo "$LOGFILE"
fi


# ============================================================
# SAVE PYTHON STATE AFTER INSTALL
# ============================================================

python -m pip freeze \
    > "$MANIFESTDIR/pip_after_${TIMESTAMP}.txt"


# ============================================================
# MANIFEST
# ============================================================

{
    echo "QWEN FURNITURE STACK"
    echo "timestamp=$TIMESTAMP"
    echo
    echo "comfyui=$COMFY"
    echo "hf_home=$HF_HOME"
    echo
    echo "qwenvl_repo=https://github.com/1038lab/ComfyUI-QwenVL.git"
    echo "qwenvl_ref=$QWENVL_REF"
    echo "qwenvl_commit=$QWENVL_COMMIT"
    echo
    echo "models:"
    echo "$DIFFUSION/qwen_image_edit_2511_bf16.safetensors"
    echo "$DIFFUSION/qwen_image_edit_2511_int8_convrot.safetensors"
    echo "$TEXT_ENCODERS/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    echo "$VAE/qwen_image_vae.safetensors"
    echo "$LORAS/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
    echo "$QWENVL_MODEL"
    echo
    echo "system:"
    uname -a
    echo
    nvidia-smi \
        --query-gpu=name,driver_version,memory.total \
        --format=csv,noheader 2>/dev/null || true
    echo
    python -VV 2>&1
    echo
    python - <<'PY'
import torch
import transformers
import huggingface_hub

print("torch=" + torch.__version__)
print("torch_cuda=" + str(torch.version.cuda))
print("transformers=" + transformers.__version__)
print("huggingface_hub=" + huggingface_hub.__version__)
PY

} > "$MANIFEST"


# ============================================================
# CLEAN FINISHED TEMP DOWNLOADS
# ============================================================

# Keep unrelated and interrupted downloads intact.


# ============================================================
# FINAL STATUS
# ============================================================

echo
echo "============================================================"
echo " INSTALLATION COMPLETE"
echo "============================================================"

echo
echo "QwenVL custom node commit:"
echo "$QWENVL_COMMIT"

echo
echo "Model directory size:"
du -sh "$MODELS"

echo
echo "Available disk:"
df -h "$COMFY"

echo
echo "Manifest:"
echo "$MANIFEST"

echo
echo "Log:"
echo "$LOGFILE"

echo
echo "Next step:"
echo "Restart ComfyUI completely."
echo

echo "Expected QwenVL nodes:"
echo "  QwenVL"
echo "  QwenVL (Advanced)"

echo
echo "============================================================"

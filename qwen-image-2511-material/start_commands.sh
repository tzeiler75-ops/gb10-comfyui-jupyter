#!/usr/bin/env bash
# Print the exact install + start sequence. No GPU work.
set -Eeuo pipefail
cat <<'EOF'
# --- Qwen3-VL-8B-Instruct download + ComfyUI start ---
# Vast, vorhandenes /workspace/ComfyUI:

cd /workspace
git clone https://github.com/tzeiler75-ops/gb10-comfyui-jupyter.git
cd gb10-comfyui-jupyter
git pull --ff-only

bash qwen-image-2511-material/install_qwenvl_mod_8b.sh

# ComfyUI neu starten, danach im Node: Qwen3-VL-8B-Instruct
if [[ -x /workspace/start-comfyui-gb10.sh ]]; then
  /workspace/start-comfyui-gb10.sh stop || true
  /workspace/start-comfyui-gb10.sh start
elif command -v supervisorctl >/dev/null; then
  supervisorctl restart comfyui || supervisorctl restart comfyui-gb10 || true
else
  echo "ComfyUI-Prozess manuell neu starten (Port 8188 oder 18188)."
fi

# GB10-Checkout statt /workspace/ComfyUI:
# COMFY=/workspace/ComfyUI-GB10 PYTHON=/workspace/venvs/comfyui-gb10/bin/python \
#   bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
# /workspace/start-comfyui-gb10.sh start
#
# Modellpfad nach Erfolg:
#   $COMFY/models/LLM/Qwen-VL/Qwen3-VL-8B-Instruct
# Node:
#   $COMFY/custom_nodes/ComfyUI-QwenVL
EOF

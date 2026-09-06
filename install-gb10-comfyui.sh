#!/usr/bin/env bash
set -Eeuo pipefail

# Native ComfyUI installation for NVIDIA GB10 / DGX Spark in a Jupyter terminal.
# Does not install or modify the host NVIDIA driver.

log()  { printf '\n[GB10] %s\n' "$*"; }
warn() { printf '\n[GB10] WARNUNG: %s\n' "$*" >&2; }
die()  { printf '\n[GB10] FEHLER: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ARCH="$(uname -m)"
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
  die "GB10 benötigt ARM64/aarch64; erkannt wurde '$ARCH'. Dieses Skript ist nicht für x86_64 gedacht."
fi

if [[ -d /workspace && -w /workspace ]]; then
  DEFAULT_ROOT=/workspace
else
  DEFAULT_ROOT="${HOME}/workspace"
fi

INSTALL_ROOT="${INSTALL_ROOT:-$DEFAULT_ROOT}"
COMFY_DIR="${COMFY_DIR:-${INSTALL_ROOT}/ComfyUI-GB10}"
VENV_DIR="${VENV_DIR:-${INSTALL_ROOT}/venvs/comfyui-gb10}"
MODEL_ROOT="${MODEL_ROOT:-${COMFY_DIR}/models}"
COMFY_REF="${COMFY_REF:-v0.33.2}"
PYTORCH_INDEX="${PYTORCH_INDEX:-https://download.pytorch.org/whl/cu130}"
PYTHON_BIN="${PYTHON_BIN:-}"
INSTALL_MANAGER="${INSTALL_MANAGER:-1}"

install_os_packages() {
  have apt-get || die 'Dieses Setup erwartet Ubuntu/Debian mit apt-get.'
  local packages=(git curl ca-certificates ffmpeg tmux build-essential cmake ninja-build
    pkg-config libgl1 libglib2.0-0 python3 python3-pip python3-venv python3-dev)
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
  elif have sudo; then
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
  else
    die "Root/sudo fehlt. Benötigte Pakete manuell installieren: ${packages[*]}"
  fi
}

select_python() {
  if [[ -n "$PYTHON_BIN" ]]; then
    have "$PYTHON_BIN" || die "PYTHON_BIN nicht gefunden: $PYTHON_BIN"
  elif have python3.12; then
    PYTHON_BIN=python3.12
  elif have python3; then
    PYTHON_BIN=python3
  else
    die 'python3 fehlt.'
  fi

  "$PYTHON_BIN" - <<'PY'
import sys
if sys.version_info < (3, 10):
    raise SystemExit("Python >=3.10 ist erforderlich")
if sys.version_info >= (3, 14):
    raise SystemExit("Für ARM64-Custom-Nodes derzeit Python 3.12/3.13 verwenden, nicht 3.14+")
print("Python:", sys.version.replace("\n", " "))
PY
}

gpu_preflight() {
  have nvidia-smi || die 'nvidia-smi fehlt: GPU-Passthrough/Host-Treiber zuerst reparieren.'
  log 'GPU- und Treiberstatus'
  nvidia-smi
  local gpu_name
  gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
  [[ -n "$gpu_name" ]] || die 'Keine NVIDIA-GPU gefunden.'
  if [[ "${gpu_name,,}" != *gb10* && "${gpu_name,,}" != *spark* ]]; then
    warn "GPU meldet '$gpu_name'. Das Setup läuft weiter, ist aber für GB10/DGX Spark ausgelegt."
  fi
}

clone_comfyui() {
  for path in "$INSTALL_ROOT" "$COMFY_DIR" "$VENV_DIR" "$MODEL_ROOT"; do
    [[ "$path" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Nur absolute Pfade ohne Leerzeichen/Sonderzeichen: $path"
  done
  mkdir -p "$INSTALL_ROOT" "$(dirname -- "$VENV_DIR")"
  if [[ -d "$COMFY_DIR/.git" ]]; then
    log "Vorhandenes ComfyUI wird nicht überschrieben: $COMFY_DIR"
    local current
    current="$(git -C "$COMFY_DIR" describe --tags --always --dirty 2>/dev/null || true)"
    log "Aktueller Stand: ${current:-unbekannt}; Ziel-Pin: $COMFY_REF"
    [[ -z "$(git -C "$COMFY_DIR" status --porcelain --untracked-files=no)" ]] || die 'ComfyUI hat lokale Änderungen.'
    [[ "$(git -C "$COMFY_DIR" rev-parse HEAD)" == "$(git -C "$COMFY_DIR" rev-parse "$COMFY_REF^{commit}" 2>/dev/null)" ]] || die 'Bestehender Checkout entspricht nicht COMFY_REF; anderes COMFY_DIR wählen.'
    return
  fi
  [[ ! -e "$COMFY_DIR" ]] || die "Ziel existiert, ist aber kein Git-Checkout: $COMFY_DIR"
  log "ComfyUI $COMFY_REF klonen"
  git clone --filter=blob:none --depth 1 --branch "$COMFY_REF" \
    https://github.com/Comfy-Org/ComfyUI.git "$COMFY_DIR"
}

create_environment() {
  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    log "Virtuelle Python-Umgebung anlegen: $VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  else
    log "Vorhandene virtuelle Umgebung verwenden: $VENV_DIR"
  fi

  local py="$VENV_DIR/bin/python"
  "$py" -m pip install --upgrade pip setuptools wheel

  log "ARM64 PyTorch mit CUDA 13.0 installieren: $PYTORCH_INDEX"
  "$py" -m pip install 'torch==2.10.0' 'torchvision==0.25.0' --index-url "$PYTORCH_INDEX"
  printf 'torch==2.10.0
torchvision==0.25.0
' > "$VENV_DIR/gb10-constraints.txt"
  export PIP_CONSTRAINT="$VENV_DIR/gb10-constraints.txt"

  log 'ComfyUI-Abhängigkeiten installieren'
  "$py" -m pip install --upgrade -r "$COMFY_DIR/requirements.txt"
  "$py" -m pip install --upgrade ipykernel huggingface_hub

  if [[ "$INSTALL_MANAGER" == 1 && -f "$COMFY_DIR/manager_requirements.txt" ]]; then
    "$py" -m pip install --upgrade -r "$COMFY_DIR/manager_requirements.txt"
  fi

  "$py" -m ipykernel install --user --name comfyui-gb10 \
    --display-name 'Python (ComfyUI GB10)'
  "$py" -m pip check
  "$py" -m pip freeze > "$VENV_DIR/installed-packages.txt"
}

configure_models() {
  local kinds=(checkpoints diffusion_models text_encoders clip_vision vae vae_approx
    loras controlnet upscale_models embeddings ipadapter style_models gligen
    hypernetworks photomaker model_patches latent_upscale_models audio_encoders)
  local kind
  for kind in "${kinds[@]}"; do mkdir -p "$MODEL_ROOT/$kind"; done

  if [[ "$MODEL_ROOT" != "$COMFY_DIR/models" ]]; then
    log "Externen Modellpfad konfigurieren: $MODEL_ROOT"
    {
      printf 'gb10_models:\n'
      printf '  base_path: "%s"\n' "$MODEL_ROOT"
      for kind in "${kinds[@]}"; do printf '  %s: %s\n' "$kind" "$kind"; done
    } > "$INSTALL_ROOT/gb10-model-paths.yaml"
  fi
}

write_environment_file() {
  local env_file="$INSTALL_ROOT/gb10-comfyui.env"
  {
    printf 'export INSTALL_ROOT=%q\n' "$INSTALL_ROOT"
    printf 'export COMFY_DIR=%q\n' "$COMFY_DIR"
    printf 'export VENV_DIR=%q\n' "$VENV_DIR"
    printf 'export MODEL_ROOT=%q\n' "$MODEL_ROOT"
    printf 'export TORCH_CUDA_ARCH_LIST=%q\n' '12.1'
    printf 'export CMAKE_CUDA_ARCHITECTURES=%q\n' '121'
    printf 'export HF_HOME=%q\n' "${HF_HOME:-${INSTALL_ROOT}/.cache/huggingface}"
    printf 'export HF_HUB_DOWNLOAD_TIMEOUT=%q\n' '60'
  } > "$env_file"
  chmod 600 "$env_file"
  [[ -f "$SCRIPT_DIR/start-comfyui-gb10.sh" ]] || die 'start-comfyui-gb10.sh muss neben dem Installer liegen.'
  install -m 755 "$SCRIPT_DIR/start-comfyui-gb10.sh" "$INSTALL_ROOT/start-comfyui-gb10.sh"
  log "Umgebung geschrieben: $env_file"
  log "Starter installiert: $INSTALL_ROOT/start-comfyui-gb10.sh"
}

validate_torch() {
  log 'PyTorch/GB10-Funktionstest'
  "$VENV_DIR/bin/python" - <<'PY'
import platform
import torch

print("machine:", platform.machine())
print("torch:", torch.__version__)
print("torch CUDA runtime:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
if not torch.cuda.is_available():
    raise SystemExit("CUDA ist in PyTorch nicht verfügbar")

name = torch.cuda.get_device_name(0)
cap = torch.cuda.get_device_capability(0)
print("GPU:", name)
print("compute capability:", f"{cap[0]}.{cap[1]}")
print("wheel arch list:", torch.cuda.get_arch_list())

# Real kernel launch, not only device discovery.
a = torch.randn((1024, 1024), device="cuda", dtype=torch.bfloat16)
b = a @ a
torch.cuda.synchronize()
assert torch.isfinite(b).all().item(), "BF16-Ergebnis enthält NaN/Inf"
c = torch.ones((64,64), device="cuda", dtype=torch.bfloat16)
assert torch.all(c @ c == 64).item(), "BF16-Korrektheitstest fehlgeschlagen"
print("BF16 CUDA matmul: OK", tuple(b.shape), b.dtype)

if cap != (12, 1):
    print("WARNUNG: GB10 wird normalerweise als Compute Capability 12.1 erkannt.")
PY
}

main() {
  log 'GB10/DGX-Spark-ComfyUI-Setup starten'
  printf 'Architektur: %s\nInstallationsroot: %s\nComfyUI: %s\nVenv: %s\nModelle: %s\n' \
    "$ARCH" "$INSTALL_ROOT" "$COMFY_DIR" "$VENV_DIR" "$MODEL_ROOT"

  if [[ -f /etc/portal.yaml ]] && command -v supervisorctl >/dev/null; then
    INSTALL_ROOT="$INSTALL_ROOT" bash "$SCRIPT_DIR/register-vast.sh" --check
  fi
  gpu_preflight
  install_os_packages
  select_python
  clone_comfyui
  create_environment
  configure_models
  write_environment_file
  validate_torch

  if [[ -f /etc/portal.yaml ]] && command -v supervisorctl >/dev/null; then
    INSTALL_ROOT="$INSTALL_ROOT" bash "$SCRIPT_DIR/register-vast.sh"
  fi
  log 'Installation erfolgreich.' 
  printf 'Start:\n  %q\n' "$INSTALL_ROOT/start-comfyui-gb10.sh"
  printf 'Web UI: http://<HOST-IP>:8188\n'
}

main "$@"

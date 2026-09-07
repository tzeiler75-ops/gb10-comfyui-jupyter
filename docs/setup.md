# Installation und Betrieb

## Vorhandenes ComfyUI

Befehle im geklonten Repository ausführen. Das FP8-Paket umfasst Diffusionsmodell, Textencoder, VAE und Lightning-LoRA (ca. 31 GB). Für einen frischen Download 35 GiB frei einplanen.

```bash
bash qwen-image-2511-material/fp8/install_qwen_fp8.sh
bash qwen-image-2511-material/fp8/install_qwen_fp8.sh check
```

Standardziel: `/workspace/ComfyUI/models`; abweichendes Ziel mit `MODEL_ROOT=/pfad/models`. Unterbrochene Downloads bleiben erhalten; fehlerhafte Dateien werden als `.bad.*` beiseitegelegt.

Für QwenVL-Mod und Qwen3-VL-8B-Instruct:

```bash
bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
```

Der Installer aktiviert auf Vast `/venv/main`. Bei anderer Python-Umgebung `PYTHON=/pfad/venv/bin/python` setzen. `COMFY` überschreibt den ComfyUI-Pfad. Der alte Node wird unter `custom_nodes_backup` gesichert; Paketlisten und Revisionen unter `setup_manifests`. Andere Python-Abhängigkeiten können sich ändern. Anschließend ComfyUI neu starten.

## Neue GB10-Installation

Ubuntu/Debian auf ARM64, funktionierendes `nvidia-smi`, Root/sudo und ein bei Vast freigegebener, unbelegter Port sind erforderlich.

```bash
INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash install-gb10-comfyui.sh
MODEL_ROOT=/workspace/models bash qwen-image-2511-material/fp8/install_qwen_fp8.sh
/workspace/start-comfyui-gb10.sh start
```

Erzeugt `/workspace/ComfyUI-GB10` mit eigener Umgebung unter `/workspace/venvs/comfyui-gb10`. Pins: ComfyUI v0.33.2, Torch 2.10.0, torchvision 0.25.0, CUDA-13-Wheels. Der Installer prüft BF16-Matrixmultiplikation; Host-Treiber bleiben unverändert.

Ist Container-Port 8188 belegt, beim Installieren `VAST_COMFY_PORT` auf einen anderen bereits freigegebenen Port setzen. Im Vast-Portal **ComfyUI GB10** öffnen.

```bash
/workspace/start-comfyui-gb10.sh status
/workspace/start-comfyui-gb10.sh stop
```

Ohne Vast-Portal startet ComfyUI über tmux auf localhost:8188; Zugang per SSH-Tunnel. Auf Vast übernimmt Supervisor den Dienst.

QwenVL-Mod für diesen separaten Checkout:

```bash
COMFY=/workspace/ComfyUI-GB10 \
PYTHON=/workspace/venvs/comfyui-gb10/bin/python \
bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
```

# Installation und Betrieb

## Vorhandenes ComfyUI

Befehle im geklonten Repository ausführen. Das FP8-Paket umfasst Diffusionsmodell, Textencoder, VAE und Lightning-LoRA (ca. 31 GB). Für einen frischen Download 35 GiB frei einplanen. Qwen3-VL-8B-Instruct braucht zusätzlich ~18 GB plus Headroom.

Startblock anzeigen:

```bash
cat qwen-image-2511-material/start_commands.sh
bash qwen-image-2511-material/start_commands.sh
```

```bash
bash qwen-image-2511-material/install_qwen_nodes.sh
bash qwen-image-2511-material/fp8/install_qwen_fp8.sh
bash qwen-image-2511-material/fp8/install_qwen_fp8.sh check
bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
```

`install_qwen_nodes.sh` klont nur `huchukato/ComfyUI-QwenVL-Mod` nach `$COMFY/custom_nodes/ComfyUI-QwenVL` und installiert Node-Requirements unter Torch-Constraint. Keine Weights. Anderes Node-Repo: `QWENVL_NODE_REPO=...`. Anderer Commit: `QWENVL_REF=...`. Qwen Image Edit 2511 braucht keinen Extra-Node (ComfyUI-Core).

Standardziel FP8: `/workspace/ComfyUI/models`; abweichendes Ziel mit `MODEL_ROOT=/pfad/models`. VL-Weights liegen fest unter `$COMFY/models/LLM/Qwen-VL/Qwen3-VL-8B-Instruct`. Unterbrochene Downloads bleiben erhalten; fehlerhafte Dateien werden als `.bad.*` beiseitegelegt.

Die Installer aktivieren auf Vast `/venv/main`. Bei anderer Python-Umgebung `PYTHON=/pfad/venv/bin/python` setzen. `COMFY` überschreibt den ComfyUI-Pfad. Der alte Node wird unter `custom_nodes_backup` gesichert; Paketlisten und Revisionen unter `setup_manifests`. Andere Python-Abhängigkeiten können sich ändern. Anschließend ComfyUI neu starten.

## Neue GB10-Installation

Ubuntu/Debian auf ARM64, funktionierendes `nvidia-smi`, Root/sudo und ein bei Vast freigegebener, unbelegter Port sind erforderlich.

```bash
INSTALL_QWENVL=1 INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash install-gb10-comfyui.sh
MODEL_ROOT=/workspace/models bash qwen-image-2511-material/fp8/install_qwen_fp8.sh
/workspace/start-comfyui-gb10.sh start
```

Ohne `INSTALL_QWENVL=1` nur ComfyUI. Nodes/VL nachziehen:

```bash
COMFY=/workspace/ComfyUI-GB10 \
PYTHON=/workspace/venvs/comfyui-gb10/bin/python \
bash qwen-image-2511-material/install_qwen_nodes.sh

COMFY=/workspace/ComfyUI-GB10 \
PYTHON=/workspace/venvs/comfyui-gb10/bin/python \
bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
/workspace/start-comfyui-gb10.sh start
```

Erzeugt `/workspace/ComfyUI-GB10` mit eigener Umgebung unter `/workspace/venvs/comfyui-gb10`. Pins: ComfyUI v0.33.2, Torch 2.10.0, torchvision 0.25.0, CUDA-13-Wheels. Der Installer prüft BF16-Matrixmultiplikation; Host-Treiber bleiben unverändert.

Ist Container-Port 8188 belegt, beim Installieren `VAST_COMFY_PORT` auf einen anderen bereits freigegebenen Port setzen. Im Vast-Portal **ComfyUI GB10** öffnen.

```bash
/workspace/start-comfyui-gb10.sh status
/workspace/start-comfyui-gb10.sh stop
```

Ohne Vast-Portal startet ComfyUI über tmux auf localhost:8188; Zugang per SSH-Tunnel. Auf Vast übernimmt Supervisor den Dienst.

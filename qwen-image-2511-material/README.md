# Qwen Image 2511 Material

Möbel-/Material-Stack für eine vorhandene ComfyUI-Installation auf Vast.ai.

## Enthalten

| Modell | Ziel unter `models/` |
|---|---|
| `qwen_image_edit_2511_bf16.safetensors` | `diffusion_models/` |
| `qwen_image_edit_2511_int8_convrot.safetensors` | `diffusion_models/` |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | `text_encoders/` |
| `qwen_image_vae.safetensors` | `vae/` |
| `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | `loras/` |
| Qwen3-VL-8B-Instruct | `LLM/Qwen-VL/Qwen3-VL-8B-Instruct/` |
| Optional: `qwen_image_edit_2511_fp8mixed.safetensors` | `diffusion_models/` |

Zusätzlich installiert das Skript [ComfyUI-QwenVL](https://github.com/1038lab/ComfyUI-QwenVL) und dessen Python-Abhängigkeiten. INT8 ist eine alternative Quantisierung; ein Geschwindigkeitsvorteil auf GB10 wurde hier nicht gemessen.

## Installation

Voraussetzung: ComfyUI ist installiert und das Terminal verwendet dessen Python-Umgebung. Standardpfad: `/workspace/ComfyUI`. Mindestens 100 GiB freien Speicher einplanen; mit zusätzlichem FP8Mixed entsprechend mehr.

```bash
cd /workspace/ComfyUI
curl -fL --retry 3 \
  https://raw.githubusercontent.com/tzeiler75-ops/gb10-comfyui-jupyter/main/qwen-image-2511-material/install_qwen_furniture_stack.sh \
  -o install_qwen_furniture_stack.sh
bash install_qwen_furniture_stack.sh
```

Für den separaten GB10-Checkout aus diesem Repository:

```bash
source /workspace/venvs/comfyui-gb10/bin/activate
COMFY=/workspace/ComfyUI-GB10 bash install_qwen_furniture_stack.sh
```

FP8Mixed zusätzlich herunterladen:

```bash
INCLUDE_FP8MIXED=1 bash install_qwen_furniture_stack.sh
```

Optional vorher `tmux new -As comfy-setup` starten. Mit `Ctrl+B`, danach `D` trennen; mit `tmux attach -t comfy-setup` zurückkehren. Anschließend ComfyUI vollständig neu starten.

## Verhalten und Grenzen

- Downloads kommen aus den im Skript angegebenen Hugging-Face-Repositories.
- Einzeldateien werden bei vorhandener, nicht leerer Zieldatei übersprungen. Das ist keine SHA-256-Integritätsprüfung. Eine defekte Zieldatei zur Seite verschieben und erneut starten.
- Qwen3-VL wird über HF synchronisiert; die benötigten Shards werden aus dem Modellindex gelesen.
- Vorhandene Torch-/Torchvision-/Torchaudio-Versionen werden durch pip-Constraints geschützt. Andere Abhängigkeiten können sich ändern. Bei unauflösbaren Anforderungen bricht pip ab.
- Bestehende QwenVL-Checkouts werden nicht automatisch aktualisiert. `QWENVL_REF=COMMIT_HASH` erlaubt eine feste Revision; lokale Änderungen verhindern einen Versionswechsel.
- Modelle folgen dem jeweiligen HF-Stand. Ein Node-Commit allein macht die gesamte Installation nicht reproduzierbar.
- Logs und Paketlisten landen unter `logs/` und `setup_manifests/`; HF-Cache unter `.cache/huggingface/`.
- Die veraltete Variable `HF_HUB_ENABLE_HF_TRANSFER` wird entfernt. `HF_XET_HIGH_PERFORMANCE=1` bleibt optional.
- Das Skript installiert keine Host-GPU-Treiber. Auf GB10 müssen kompatible ARM64-Python-/CUDA-Pakete bereits vorhanden sein.

## Prüfstatus

Shell-Syntax und eingebettete Python-Blöcke lokal geprüft. Kein vollständiger Download-, Installations- oder Bildgenerierungstest auf GB10 durchgeführt. Paketkonflikte werden am Ende gemeldet; erfolgreiche Downloads allein belegen keine funktionierende Inferenz.

## Quellen

- [ComfyUI-Diffusionsmodelle](https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/tree/main/split_files/diffusion_models)
- [Textencoder](https://huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged/tree/main/split_files/text_encoders)
- [VAE](https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/tree/main/split_files/vae)
- [Lightning-LoRA](https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning)
- [Qwen3-VL](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)

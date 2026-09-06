# Qwen Image 2511 Material – FP8

Download-Version mit genau vier Dateien:

- diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors
- text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
- vae/qwen_image_vae.safetensors
- loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors

FP8 bezieht sich auf Diffusionsmodell und Textencoder. VAE und Lightning-LoRA behalten ihre Originalpräzision. Kein zusätzliches BF16-/INT8-Diffusionsmodell, Qwen3-VL oder Custom Node. Keine Änderungen an Python, Torch oder GPU-Treibern.

```bash
cd /workspace/ComfyUI
curl -fL --retry 3 https://raw.githubusercontent.com/tzeiler75-ops/gb10-comfyui-jupyter/main/qwen-image-2511-material/fp8/install_qwen_fp8.sh -o install_qwen_fp8.sh
bash install_qwen_fp8.sh
```

Standardziel: /workspace/ComfyUI/models. Bei gemeinsamem GB10-Modellverzeichnis:

```bash
MODEL_ROOT=/workspace/models bash install_qwen_fp8.sh
```

Nur vorhandene Dateien prüfen:

```bash
bash install_qwen_fp8.sh check
```

Ca. 31 GB Downloads; für einen frischen Download 35 GiB frei einplanen. Vorhandene Dateien werden per SHA-256 geprüft und übersprungen. Unterbrochene Downloads werden fortgesetzt. aria2c verwendet acht Verbindungen, falls vorhanden; sonst curl. Fehlerhafte Downloads werden als .bad-Dateien aufgehoben. Diese belegen weiter Speicher.

Shell-Syntax geprüft; kein vollständiger Modell-Download oder GB10-Inferenztest durchgeführt. Nach Abschluss Modelle in ComfyUI neu einlesen oder ComfyUI neu starten.

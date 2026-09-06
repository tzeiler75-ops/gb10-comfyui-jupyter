# KI-gestützte Möbel- und Materialvarianten

Technische Grundlage für Bildbearbeitung und Bildanalyse mit ComfyUI auf NVIDIA GB10 / Vast.ai.

## Umsetzung

- **Qwen Image Edit 2511 FP8:** Modell-Download mit Fortsetzung und SHA-256-Prüfung.
- **Qwen3-VL-8B-Instruct:** Bildanalyse über QwenVL-Mod, mit Node-Backup und Schutz der installierten Torch-Version.
- **GB10-Setup:** isolierte Python-Umgebung, Jupyter-Kernel und Dienstverwaltung.

Der Projektbeitrag liegt in der Installation, Integration und Prüfung dieser Komponenten. Modelle und Custom Node stammen aus den verlinkten Open-Source-Projekten.

## Start

Für ein Vast-Image mit vorhandenem `/workspace/ComfyUI`:

```bash
cd /workspace
git clone https://github.com/tzeiler75-ops/gb10-comfyui-jupyter.git
cd gb10-comfyui-jupyter
bash qwen-image-2511-material/fp8/install_qwen_fp8.sh
```

Optional für Bildanalyse:

```bash
bash qwen-image-2511-material/install_qwenvl_mod_8b.sh
```

[Installation und Betrieb](docs/setup.md)

## Prüfstand

Auf einer GB10-Instanz: ComfyUI erreichbar, PyTorch 2.10 / CUDA 13 erkannt und alle vier FP8-Paketdateien per SHA-256 geprüft. Die Skriptsyntax ist geprüft. Ein vollständiger Bildworkflow und die QwenVL-Mod-Inferenz sind noch nicht validiert.

## Komponenten

[ComfyUI](https://github.com/Comfy-Org/ComfyUI) · [Qwen Image Edit](https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI) · [Lightning-LoRA](https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning) · [Qwen3-VL](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct) · [QwenVL-Mod](https://github.com/huchukato/ComfyUI-QwenVL-Mod)

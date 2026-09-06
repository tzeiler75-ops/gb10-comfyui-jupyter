# GB10 ComfyUI + Jupyter-Kernel

Installer für eine neue ARM64-/aarch64-Instanz mit NVIDIA GB10. Basierend auf dem bereitgestellten Archiv, mit Port-Prüfung, separatem Checkout, geschützter Modellkonfiguration und Vast-Supervisor-Integration.

## Neue Vast-Instanz

- ARM64-PyTorch/Jupyter-Image, Ubuntu/Debian, Python 3.12 empfohlen.
- GPU muss vorab durch `nvidia-smi` sichtbar sein.
- Bei Erstellung TCP-Port **8188** freigeben. Ein Image ohne vorinstalliertes ComfyUI wählen, damit dieser Port frei ist.
- Das vorhandene Jupyter-Terminal öffnen. Dieses Setup installiert einen Jupyter-Kernel, keinen neuen Jupyter-Server.

## Installation aus dem Repository

Öffentliches Repository:

```bash
cd /workspace
git clone https://github.com/tzeiler75-ops/gb10-comfyui-jupyter.git
cd gb10-comfyui-jupyter
INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash install-gb10-comfyui.sh
/workspace/start-comfyui-gb10.sh
```

Der Installer benutzt `/workspace/ComfyUI-GB10` und `/workspace/venvs/comfyui-gb10`. Ein vorhandener Checkout muss zum gewünschten ComfyUI-Tag passen; andernfalls bricht der Installer ab. ComfyUI ist auf `v0.33.2`, PyTorch auf `2.10.0` und torchvision auf `0.25.0` gepinnt. Python-Abhängigkeiten sind nicht vollständig eingefroren. Das tatsächlich installierte Paketverzeichnis wird gespeichert.

## Installation aus einem Gist

`setup-gb10.sh` ist die eigenständige Variante: alle drei Installations-/Betriebsskripte sind enthalten. Das veröffentlichte Gist lädt dieses eigenständige Skript aus einer festen Repository-Version und prüft dessen SHA-256. Die Raw-URL des Gists einsetzen:

```bash
curl -fL 'GIST_RAW_URL' -o /workspace/setup-gb10.sh
INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash /workspace/setup-gb10.sh
/workspace/start-comfyui-gb10.sh
```

## Betrieb

Auf Vast mit `/etc/portal.yaml` und Supervisor wird der Dienst `comfyui-gb10` eingerichtet und gestartet. Caddy wird nach gesicherter Portal-Konfiguration neu gestartet. ComfyUI bindet intern an `127.0.0.1:18189`, der geschützte externe Container-Port ist `8188`. Im Vast-Portal **ComfyUI GB10** öffnen; der öffentliche Host-Port ist der von Vast zugewiesene Port, nicht zwangsläufig 8188.

```bash
/workspace/start-comfyui-gb10.sh status
/workspace/start-comfyui-gb10.sh stop
/workspace/start-comfyui-gb10.sh start
```

Ist 8188 durch einen anderen Portal-Eintrag belegt, vor Instanz-Erstellung einen anderen Port einplanen und bei der Installation z. B. `VAST_COMFY_PORT=10100` setzen. Bereits vorhandene ComfyUI-Dienste werden nicht ersetzt.

Ohne Vast-Portal/Supervisor verwendet der Starter tmux und bindet standardmäßig nur an localhost:8188. Zugang per SSH-Tunnel:

```bash
ssh -p SSH_PORT -L 8188:127.0.0.1:8188 root@HOST
```

Dann lokal `http://localhost:8188` öffnen. `tmux attach -t comfyui-gb10` zeigt die Konsole. Auf Vast im Supervisor-Modus ist tmux nicht beteiligt.

## Modelle und Grenzen

Keine Modelle werden automatisch heruntergeladen. `MODEL_ROOT=/workspace/models` erzeugt Modell-Unterordner und eine separate `gb10-model-paths.yaml`; vorhandene `extra_model_paths.yaml` bleibt erhalten. Das Setup installiert keine NVIDIA-Host-Treiber, xformers, FlashAttention oder SageAttention.

`/workspace` ist auf Vast nicht automatisch ein persistentes Volume. Vor Recycle/Destroy Daten extern sichern, sofern kein Volume gemountet ist.

## Prüfstatus

Lokal geprüft: Shell-Syntax, ARM64-Schutz auf x86, Starter-Fehlerpfade und Inhalt der eigenständigen Gist-Version. Ein vollständiger Installations-/Bildgenerierungstest auf einer neuen GB10-Instanz steht aus. Der Installer führt dort BF16-Matrixmultiplikation, Ergebnisprüfung, `pip check` und beim Start einen HTTP-Gesundheitstest aus. Ein GPU-Test in der bisherigen Instanz ist kein Test dieser neuen Installation.

## GitHub und Gist veröffentlichen

Mit installierter [GitHub CLI](https://cli.github.com/) und eigener Anmeldung:

```bash
gh auth login
bash publish-github.sh
```

Das erstellt ein **öffentliches** Repository und ein **öffentliches** Gist und zeigt anschließend die konkreten Installationsbefehle. Keine SSH-Schlüssel oder Zugangsdaten sind Teil dieses Pakets.

## Referenzen

- [ComfyUI v0.33.2](https://github.com/Comfy-Org/ComfyUI/releases/tag/v0.33.2)
- [PyTorch CUDA-13-Index](https://download.pytorch.org/whl/cu130)
- [Vast-Base-Image](https://github.com/vast-ai/base-image)

Der Tag wurde übernommen und auf Existenz geprüft; eine aktuelle NVIDIA-Zertifizierung wird hier nicht behauptet.

#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v gh >/dev/null || { echo 'GitHub CLI fehlt: https://cli.github.com/'; exit 1; }
gh auth status
account="$(gh api user --jq .login)"
repo="$account/gb10-comfyui-jupyter"
if [[ ! -d .git ]]; then
  git init -b main
  git add .gitignore README.md install-gb10-comfyui.sh start-comfyui-gb10.sh register-vast.sh setup-gb10.sh publish-github.sh
  git -c user.name="$account" -c user.email="$account@users.noreply.github.com" commit -m 'Add GB10 ComfyUI installer'
fi
if git remote get-url origin >/dev/null 2>&1; then
  echo 'Origin bereits vorhanden; Veröffentlichung nicht automatisch wiederholt.' >&2
  exit 1
fi
gh repo create "$repo" --public --source=. --remote=origin --push \
  --description 'ARM64 NVIDIA GB10 ComfyUI installer with Jupyter kernel and Vast supervisor support'
gist_url="$(gh gist create --public --desc 'GB10 ComfyUI + Jupyter kernel setup for a fresh ARM64 instance' setup-gb10.sh)"
gist_id="${gist_url##*/}"
raw_url="$(gh api "gists/$gist_id" --jq '.files["setup-gb10.sh"].raw_url')"
printf '\nRepository: https://github.com/%s\nGist: %s\n\n' "$repo" "$gist_url"
printf 'Repository-Installation:\ncd /workspace && git clone https://github.com/%s.git && cd gb10-comfyui-jupyter && INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash install-gb10-comfyui.sh\n\n' "$repo"
printf 'Gist-Installation:\ncurl -fL %q -o /workspace/setup-gb10.sh && INSTALL_ROOT=/workspace MODEL_ROOT=/workspace/models bash /workspace/setup-gb10.sh\n' "$raw_url"

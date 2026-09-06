#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -d /workspace && -w /workspace ]]; then
  DEFAULT_ROOT=/workspace
else
  DEFAULT_ROOT="${HOME}/workspace"
fi

INSTALL_ROOT="${INSTALL_ROOT:-$DEFAULT_ROOT}"
ENV_FILE="${GB10_ENV_FILE:-${INSTALL_ROOT}/gb10-comfyui.env}"
[[ -f "$ENV_FILE" ]] || { printf 'Fehlt: %s\nZuerst install-gb10-comfyui.sh ausführen.\n' "$ENV_FILE" >&2; exit 1; }

# shellcheck disable=SC1090
source "$ENV_FILE"

LISTEN="${LISTEN:-127.0.0.1}"
PORT="${PORT:-8188}"
SESSION="${TMUX_SESSION:-comfyui-gb10}"
LOG_DIR="${LOG_DIR:-${INSTALL_ROOT}/logs}"
mkdir -p "$LOG_DIR"

foreground() {
  cd "$COMFY_DIR"
  local args=(main.py --listen "$LISTEN" --port "$PORT")
  [[ ! -f "$INSTALL_ROOT/gb10-model-paths.yaml" ]] || args+=(--extra-model-paths-config "$INSTALL_ROOT/gb10-model-paths.yaml")
  [[ "${ENABLE_MANAGER:-1}" == 1 ]] && args+=(--enable-manager)
  exec "$VENV_DIR/bin/python" "${args[@]}"
}

if [[ -f "$INSTALL_ROOT/gb10-supervisor" && "${1:-start}" != foreground && "${1:-}" != --foreground ]]; then
  case "${1:-start}" in
    start|tmux|--tmux)
      if ! supervisorctl status comfyui-gb10 | grep -q RUNNING; then supervisorctl start comfyui-gb10; fi ;;
    status) supervisorctl status comfyui-gb10 ;;
    stop) supervisorctl stop comfyui-gb10 ;;
    *) printf 'Aufruf: %s [start|status|stop|foreground]\n' "$0"; exit 2 ;;
  esac
  exit
fi

case "${1:-tmux}" in
  foreground|--foreground)
    foreground
    ;;
  start|tmux|--tmux)
    if ! command -v tmux >/dev/null 2>&1; then
      printf 'tmux fehlt; starte im Vordergrund.\n' >&2
      foreground
    fi
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      printf 'Session läuft bereits: %s\n' "$SESSION"
    else
      "$VENV_DIR/bin/python" -c 'import socket,sys; s=socket.socket(); s.bind((sys.argv[1],int(sys.argv[2])))' "$LISTEN" "$PORT"
      cmd="$(printf '%q ' env "GB10_ENV_FILE=$ENV_FILE" "LISTEN=$LISTEN" "PORT=$PORT" "ENABLE_MANAGER=${ENABLE_MANAGER:-1}" "$0" --foreground)2>&1 | tee -a $(printf '%q' "$LOG_DIR/comfyui.log")"
      tmux new-session -d -s "$SESSION" "$cmd"
      ready=0
      for ((attempt=0; attempt<120; attempt++)); do
        tmux has-session -t "$SESSION" 2>/dev/null || break
        if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/system_stats" >/dev/null; then ready=1; break; fi
        sleep 1
      done
      [[ "$ready" == 1 ]] || { printf 'Start fehlgeschlagen oder dauert länger. Log: %s\n' "$LOG_DIR/comfyui.log" >&2; exit 1; }
      printf 'ComfyUI erreichbar: tmux %s\n' "$SESSION"
    fi
    printf 'UI: http://<HOST-IP>:%s\nLogs: %s\n' "$PORT" "$LOG_DIR/comfyui.log"
    printf 'Konsole: tmux attach -t %q\n' "$SESSION"
    ;;
  status)
    tmux has-session -t "$SESSION" 2>/dev/null && printf 'running\n' || { printf 'stopped\n'; exit 1; }
    ;;
  stop)
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    printf 'Session beendet: %s\n' "$SESSION"
    ;;
  *)
    printf 'Aufruf: %s [tmux|foreground|status|stop]\n' "$0" >&2
    exit 2
    ;;
esac

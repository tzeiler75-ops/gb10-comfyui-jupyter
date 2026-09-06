#!/usr/bin/env bash
set -Eeuo pipefail
INSTALL_ROOT="${INSTALL_ROOT:-/workspace}"
EXTERNAL_PORT="${VAST_COMFY_PORT:-8188}"
INTERNAL_PORT=18189
[[ $(id -u) == 0 ]] || { echo 'Vast-Registrierung benötigt root.' >&2; exit 1; }
python3 - "$EXTERNAL_PORT" "$INTERNAL_PORT" <<'PY'
import os,socket,sys,yaml
external,internal=map(int,sys.argv[1:])
assert 1 <= external <= 65535 and external != internal
assert os.environ.get(f'VAST_TCP_PORT_{external}'), f'Port {external} wurde bei Vast nicht freigegeben.'
d=yaml.safe_load(open('/etc/portal.yaml')) or {}
apps=d.get('applications',{})
for name,app in apps.items():
    if name != 'ComfyUI GB10':
        assert int(app.get('external_port',0)) != external, f'Port {external} gehört bereits {name}; anderes VAST_COMFY_PORT wählen.'
if 'ComfyUI GB10' not in apps:
    for port in (external,internal):
        with socket.socket() as s: s.bind(('127.0.0.1',port))
PY
[[ ${1:-} != --check ]] || exit 0
[[ -f "$INSTALL_ROOT/gb10-comfyui.env" ]]
[[ "$INSTALL_ROOT" =~ ^/[a-zA-Z0-9_./-]+$ ]]
mkdir -p /opt/supervisor-scripts /etc/supervisor/conf.d
cat > /opt/supervisor-scripts/comfyui-gb10.sh <<EOF
#!/bin/bash
. /opt/supervisor-scripts/utils/logging.sh
. /opt/supervisor-scripts/utils/environment.sh
. /opt/supervisor-scripts/utils/exit_portal.sh "ComfyUI GB10"
export INSTALL_ROOT="$INSTALL_ROOT"
export LISTEN=127.0.0.1 PORT=$INTERNAL_PORT
pty "$INSTALL_ROOT/start-comfyui-gb10.sh" foreground 2>&1
EOF
chmod 755 /opt/supervisor-scripts/comfyui-gb10.sh
cat > /etc/supervisor/conf.d/comfyui-gb10.conf <<'EOF'
[program:comfyui-gb10]
environment=PROC_NAME="%(program_name)s"
command=/opt/supervisor-scripts/comfyui-gb10.sh
autostart=true
autorestart=unexpected
stopasgroup=true
killasgroup=true
stdout_logfile=/dev/stdout
redirect_stderr=true
stdout_logfile_maxbytes=0
EOF
python3 - "$EXTERNAL_PORT" "$INTERNAL_PORT" <<'PY'
import sys,yaml,shutil,datetime,os
p='/etc/portal.yaml'
shutil.copy2(p,p+'.gb10-backup-'+datetime.datetime.now().strftime('%Y%m%d%H%M%S%f'))
d=yaml.safe_load(open(p)) or {}
d.setdefault('applications',{})['ComfyUI GB10']={
 'hostname':'localhost','external_port':int(sys.argv[1]),
 'internal_port':int(sys.argv[2]),'open_path':'/','name':'ComfyUI GB10'}
with open(p+'.gb10-tmp','w') as f: yaml.safe_dump(d,f,sort_keys=False)
os.replace(p+'.gb10-tmp',p)
PY
touch "$INSTALL_ROOT/gb10-supervisor"
supervisorctl reread
supervisorctl update
supervisorctl restart comfyui-gb10
supervisorctl restart caddy
for ((attempt=0; attempt<120; attempt++)); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$INTERNAL_PORT/api/system_stats" >/dev/null; then
    echo 'ComfyUI GB10 ist erreichbar. Im Vast-Portal öffnen (vorhandene Token-Anmeldung).'
    exit 0
  fi
  sleep 1
done
echo 'ComfyUI ist noch nicht erreichbar. Prüfe supervisorctl status und /var/log/portal/comfyui-gb10.log.' >&2
exit 1

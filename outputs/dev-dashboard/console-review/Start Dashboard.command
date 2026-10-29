#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [[ ! -f runner-config.json ]]; then
  print 'Missing runner-config.json. Follow README.md to select the app and engine checkouts.'
  exit 1
fi
if python3 -c 'import json,urllib.request; d=json.load(urllib.request.urlopen("http://127.0.0.1:18763/health",timeout=2)); assert d.get("service")=="Dakhl local runner"' >/dev/null 2>&1; then
  open http://127.0.0.1:18763/connect
  exit 0
fi
python3 -c 'import subprocess,time; time.sleep(1); subprocess.run(["open","http://127.0.0.1:18763/connect"],check=False)' &
exec python3 runner/server.py --config runner-config.json

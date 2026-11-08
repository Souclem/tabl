#!/bin/bash
# Surveille en continu les simulateurs iOS démarrés et capture le log
# système (process Runner / subsystem flutter) de chacun vers
# logs/simulateur.log, à la racine du dépôt.
#
# Lancé à la main (`./scripts/log_watcher.sh`), ce script tourne tant que
# le terminal reste ouvert.
#
# Pour un démarrage automatique à chaque connexion Mac (LaunchAgent
# be.tabl.log-watcher), macOS bloque l'accès au dossier Desktop pour les
# process d'arrière-plan — une copie de ce script est donc déployée hors
# de Desktop, dans "~/Library/Application Support/tabl-dev/log_watcher.sh",
# qui écrit ses logs au même endroit (pas dans ce dépôt). Si tu modifies le
# comportement ici, reproduis le changement dans la copie déployée.
#
# N'importe quel lancement de l'app Tabl sur un simulateur — depuis Xcode,
# flutter run, ou un tap sur l'icône — finit dans le fichier de log actif.

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FICHIER_LOG="$RACINE/logs/simulateur.log"
DOSSIER_PID="$RACINE/logs/.watcher-pids"
mkdir -p "$RACINE/logs" "$DOSSIER_PID"

echo "--- Watcher démarré $(date) ---" >> "$FICHIER_LOG"

while true; do
  # Simulateurs actuellement démarrés (un ID par ligne).
  demarres=$(xcrun simctl list devices 2>/dev/null | grep "(Booted)" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')

  for device in $demarres; do
    fichier_pid="$DOSSIER_PID/$device.pid"
    if [ -f "$fichier_pid" ] && kill -0 "$(cat "$fichier_pid")" 2>/dev/null; then
      continue  # déjà capturé pour cet appareil
    fi
    echo "--- Capture démarrée $(date) sur $device ---" >> "$FICHIER_LOG"
    xcrun simctl spawn "$device" log stream \
      --level debug \
      --style compact \
      --predicate 'process == "Runner" OR (subsystem == "flutter")' \
      >> "$FICHIER_LOG" 2>&1 &
    echo $! > "$fichier_pid"
  done

  # Nettoie les captures dont l'appareil a été éteint.
  for fichier_pid in "$DOSSIER_PID"/*.pid; do
    [ -e "$fichier_pid" ] || continue
    device=$(basename "$fichier_pid" .pid)
    if ! echo "$demarres" | grep -q "$device"; then
      pid=$(cat "$fichier_pid")
      kill "$pid" 2>/dev/null
      rm -f "$fichier_pid"
    fi
  done

  sleep 5
done

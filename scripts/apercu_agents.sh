#!/bin/bash
# Lance sur le simulateur la version la plus récente du travail des agents.
#
# Les agents Paperclip travaillent chacun sur une branche agent/TAB-…, jamais
# fusionnée tant que le propriétaire ne l'a pas fait. Ce script assemble, dans
# une copie à part (dossier « apercu » à côté des copies des agents), la branche
# mac-mini + toutes les branches d'agents modifiées ces derniers jours (seulement
# les plus avancées : une branche déjà contenue dans une autre est sautée). Une
# branche qui entre en conflit est laissée de côté et signalée. Rien n'est poussé,
# le dossier du dépôt n'est pas touché.
#
# Puis il construit l'app (mode debug) et l'installe sur le simulateur, à la
# place de celle qui y est : les données de l'app (connexion…) sont gardées.
#
# Usage : scripts/apercu_agents.sh [simulateur] [jours]
#         (par défaut : « iPhone 17 », branches modifiées depuis 3 jours)
set -euo pipefail

DEPOT="$(cd "$(dirname "$0")/.." && pwd)"
SIMULATEUR="${1:-iPhone 17}"
JOURS="${2:-3}"
APERCU="$HOME/.paperclip/worktrees/tabl/apercu"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"
command -v "$FLUTTER" >/dev/null 2>&1 || FLUTTER=flutter

cd "$DEPOT"
depuis=$(( $(date +%s) - JOURS * 86400 ))

# 1. Les branches d'agents récentes qui ont du neuf par rapport à mac-mini.
candidates=()
while read -r date branche; do
  [ "$date" -ge "$depuis" ] || continue
  [ "$(git rev-list --count "mac-mini..$branche")" -gt 0 ] || continue
  candidates+=("$branche")
done < <(git for-each-ref refs/heads/agent --sort=committerdate --format="%(committerdate:unix) %(refname:short)")

# 2. Seulement les plus avancées : on saute une branche contenue dans une autre.
#    Deux branches au même commit (une tâche reprise par une autre) sont
#    chacune « contenue » dans l'autre : on n'en garde qu'une, la plus récente.
branches=()
vus=" "
for (( i=${#candidates[@]}-1; i>=0; i-- )); do
  b="${candidates[$i]}"
  commit=$(git rev-parse "$b")
  case "$vus" in *" $commit "*) continue ;; esac
  vus="$vus$commit "
  contenue=0
  for autre in "${candidates[@]}"; do
    [ "$(git rev-parse "$autre")" = "$commit" ] && continue
    if git merge-base --is-ancestor "$b" "$autre"; then contenue=1; break; fi
  done
  [ "$contenue" -eq 1 ] || branches=("$b" "${branches[@]+"${branches[@]}"}")
done
if [ "${#branches[@]}" -eq 0 ]; then
  echo "Aucune branche d'agent récente : rien de neuf par rapport à mac-mini."
  exit 0
fi

# 3. La copie « apercu », remise à mac-mini puis fusion de chaque branche.
if [ ! -d "$APERCU" ]; then
  git worktree add --detach "$APERCU" mac-mini >/dev/null
fi
cd "$APERCU"
git merge --abort >/dev/null 2>&1 || true
git checkout --detach --force mac-mini >/dev/null 2>&1
git reset --hard mac-mini >/dev/null
git clean -fdq -e app/build -e app/.dart_tool

fusionnees=(); laissees=()
for b in "${branches[@]}"; do
  nom=$(echo "$b" | grep -oE 'TAB-[0-9]+' | head -1)
  if git -c user.name="Aperçu" -c user.email="apercu@localhost" merge --no-edit -q "$b" >/dev/null 2>&1; then
    fusionnees+=("$nom")
  else
    git merge --abort >/dev/null 2>&1 || true
    laissees+=("$nom")
  fi
done
echo "Assemblé : mac-mini + ${fusionnees[*]:-rien}"
[ "${#laissees[@]}" -eq 0 ] || echo "Laissées de côté (conflit avec les autres) : ${laissees[*]}"

# 4. Construire et installer sur le simulateur.
cp "$DEPOT/app/.env" app/.env
xcrun simctl boot "$SIMULATEUR" 2>/dev/null || true
open -a Simulator
cd app
echo "Construction de l'app (quelques minutes)…"
"$FLUTTER" build ios --simulator --debug --dart-define-from-file=.env >/tmp/apercu_build_$$.log 2>&1 || {
  echo "La construction a échoué. Fin du journal :"; tail -30 /tmp/apercu_build_$$.log; exit 1; }
rm -f /tmp/apercu_build_$$.log
APP=build/ios/iphonesimulator/Runner.app
ID=$(/usr/bin/plutil -extract CFBundleIdentifier raw "$APP/Info.plist")
xcrun simctl terminate "$SIMULATEUR" "$ID" 2>/dev/null || true
xcrun simctl install "$SIMULATEUR" "$APP"
xcrun simctl launch "$SIMULATEUR" "$ID" >/dev/null
echo "Lancée sur « $SIMULATEUR » : la version des agents (${fusionnees[*]:-mac-mini})."

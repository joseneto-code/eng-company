#!/usr/bin/env bash
# Instala os agentes e skills da Eng Company no Claude Code.
#
#   ./scripts/install.sh                          # global (~/.claude)
#   ./scripts/install.sh --project /repo/produto  # num projeto
#   ./scripts/install.sh --dry-run

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="${2:?--project exige um caminho}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
  esac
done

if [ -n "$project" ]; then
  [ -d "$project" ] || { echo "Projeto nao encontrado: $project" >&2; exit 1; }
  dest="$project/.claude"; scope="projeto ($project)"
else
  dest="$HOME/.claude"; scope="global (~/.claude)"
fi

agents_src="$repo/.claude/agents"
skills_src="$repo/skills"
for p in "$agents_src" "$skills_src"; do
  [ -d "$p" ] || { echo "Nao encontrado: $p (rode a partir do repo clonado)" >&2; exit 1; }
done

echo "Eng Company -> $scope"

if [ "$dry_run" -eq 1 ]; then
  echo "[dry-run] copiaria:"
  echo "  $agents_src/*.md -> $dest/agents/"
  echo "  $skills_src/eng-* -> $dest/skills/"
  exit 0
fi

mkdir -p "$dest/agents" "$dest/skills"
cp -f "$agents_src"/*.md "$dest/agents/"
cp -Rf "$skills_src"/eng-* "$dest/skills/"

echo
echo "Agentes:"
for f in "$dest"/agents/eng-*.md; do echo "  $(basename "$f" .md)"; done
echo
echo "Skills:"
for d in "$dest"/skills/eng-*/; do echo "  $(basename "$d")"; done
echo
echo "Pronto. Abra o Claude Code no repo do seu produto e chame:"
echo "  usa o eng-ceo: <seu pedido>"
echo
echo "Antes de usar em producao, preencha agents/ceo/references/mandato.md"

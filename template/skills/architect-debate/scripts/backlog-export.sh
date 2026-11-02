#!/bin/sh
# backlog-export.sh <caso> - BACKLOG.md para backlog.csv (import Jira/Linear/GitHub Projects), backlog.json
# e backlog-gh.sh (gh issue create por item, para revisar antes de rodar). Imprime o resumo por fase e o caminho critico.
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: backlog-export.sh <caso>}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
B="$CASE_DIR/BACKLOG.md"
[ -s "$B" ] || { echo "erro: $B ausente" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "erro: jq nao encontrado" >&2; exit 2; }
awk -v modo=tsv -f "$SCRIPT_DIR/backlog.awk" "$B" | jq -R -s '
  split("\n") | map(select(length > 0) | split("\t") | {
    id: .[0], fase: .[1], epico: .[2], titulo: .[3], aceite: .[4], origem: .[5], estimativa: .[6],
    dias: (.[7] | tonumber), deps: (.[8] | split(" ") | map(select(length > 0))),
    tags: (.[9] | split(" ") | map(select(length > 0))), bloqueia_fase: (.[10] == "sim"), status: .[11] })' > "$CASE_DIR/backlog.json"
jq -r '(["ID","Summary","Description","Epic","Phase","Estimate","Days","Depends on","Labels","Blocks phase","Status"] | @csv),
  (.[] | [.id, .titulo, ("Aceite: " + .aceite + "\nOrigem: " + .origem), .epico, .fase, .estimativa, .dias,
    (.deps | join(" ")), (.tags | join(" ")), (if .bloqueia_fase then "sim" else "nao" end), .status] | @csv)' \
  "$CASE_DIR/backlog.json" > "$CASE_DIR/backlog.csv"
{
  echo '#!/bin/sh'
  echo '# gerado por backlog-export.sh: revise antes de rodar; cria 1 issue por item aberto no repo atual (gh auth login antes).'
  echo 'set -eu'
  jq -r '.[] | select(.status == "aberto") |
    "gh issue create --title " + ((.id + " " + .titulo) | @sh) + " --body " +
    (("Aceite: " + .aceite + "\n\nOrigem: " + .origem + "\nFase: " + .fase + "\nEstimativa: " + .estimativa +
      (if (.deps | length) > 0 then "\nDepende de: " + (.deps | join(", ")) else "" end)) | @sh) +
    ([.tags[] | " --label " + @sh] | join(""))' "$CASE_DIR/backlog.json"
} > "$CASE_DIR/backlog-gh.sh"
awk -v modo=resumo -f "$SCRIPT_DIR/backlog.awk" "$B"
printf '%s\n' "$CASE_DIR/backlog.csv" "$CASE_DIR/backlog.json" "$CASE_DIR/backlog-gh.sh"

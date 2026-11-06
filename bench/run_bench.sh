#!/usr/bin/env bash
# =====================================================================
# run_bench.sh : exécute chaque requête de bench/requetes/ plusieurs fois
#                sur chaque configuration et écrit les durées dans un CSV.
#
# À lancer DANS la VM Cloudera, depuis la racine du dépôt :
#   bash bench/run_bench.sh                 5 exécutions, configurations par défaut
#   bash bench/run_bench.sh 3               3 exécutions
#   bash bench/run_bench.sh 5 "avant partitions apres_hive apres_impala"
#   REQUETES="kpi2 kpi3 q9" bash bench/run_bench.sh 1   une partie des requêtes
#
# Configurations :
#   avant         Hive sur chu_bench_brut, conversions de jointure coupées
#   partitions    Hive sur chu_bench_part (facultatif, bench/01_base_partitions.sql)
#   apres_hive    Hive sur chu_dw, réglages de lecture optimisés
#   apres_impala  Impala sur chu_dw
#
# Avant de lancer : VM redémarrée, services inutiles arrêtés dans Cloudera
# Manager (HBase, Oozie, Spark, Solr...), rien d'autre ouvert sur le PC.
#
# Durée retenue : celle affichée par Beeline ou impala-shell pour la
# requête. La durée « mur » (lancement du client compris) est gardée à
# titre de contrôle.
# =====================================================================
set -u

NB_EXEC="${1:-5}"
CONFIGS="${2:-avant apres_hive apres_impala}"
REQUETES="${REQUETES:-}"
HOTE="${HOTE:-quickstart.cloudera}"

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
DOSSIER_REQ="$RACINE/bench/requetes"
DOSSIER_RES="$RACINE/resultats/benchmark"
HORODATAGE="$(date +%Y-%m-%d_%H%M)"
SORTIE="$DOSSIER_RES/mesures_$HORODATAGE.csv"
JOURNAL="$DOSSIER_RES/journal_$HORODATAGE.log"
mkdir -p "$DOSSIER_RES"

HIVE_AVANT="--hiveconf hive.auto.convert.join=false --hiveconf hive.cbo.enable=false"
HIVE_APRES="--hiveconf hive.auto.convert.join=true \
--hiveconf hive.auto.convert.sortmerge.join=true \
--hiveconf hive.optimize.bucketmapjoin=true \
--hiveconf hive.optimize.bucketmapjoin.sortedmerge=true \
--hiveconf hive.exec.parallel=true"

# Exécute une requête une fois. Affiche : duree_s;duree_mur_s;statut
executer() {
  local moteur="$1" base="$2" options="$3" fichier="$4"
  local err debut fin code duree mur statut
  err="$(mktemp)"
  debut="$(date +%s.%N)"
  if [ "$moteur" = "hive" ]; then
    # $options n'est pas entre guillemets : il contient plusieurs arguments
    beeline -u "jdbc:hive2://$HOTE:10000/$base" -n cloudera $options \
      -f "$fichier" > /dev/null 2> "$err"
    code=$?
    duree="$(grep -oE '\([0-9.]+ seconds\)' "$err" | tail -n 1 | grep -oE '[0-9.]+')"
  else
    impala-shell -i "$HOTE" -d "$base" -f "$fichier" > /dev/null 2> "$err"
    code=$?
    duree="$(grep -oE 'in [0-9.]+s' "$err" | tail -n 1 | grep -oE '[0-9.]+')"
  fi
  fin="$(date +%s.%N)"
  mur="$(awk -v d="$debut" -v f="$fin" 'BEGIN { printf "%.3f", f - d }')"
  if [ "$code" -eq 0 ] && [ -n "$duree" ]; then statut="ok"; else statut="erreur"; fi
  {
    echo "=== $(date '+%H:%M:%S') $moteur $base $(basename "$fichier") : $statut"
    cat "$err"
  } >> "$JOURNAL"
  rm -f "$err"
  echo "${duree};${mur};${statut}"
}

echo "configuration;moteur;base;requete;execution;duree_s;duree_mur_s;statut" > "$SORTIE"

for config in $CONFIGS; do
  case "$config" in
    avant)        moteur="hive";   base="chu_bench_brut"; options="$HIVE_AVANT" ;;
    partitions)   moteur="hive";   base="chu_bench_part"; options="$HIVE_AVANT" ;;
    apres_hive)   moteur="hive";   base="chu_dw";         options="$HIVE_APRES" ;;
    apres_impala) moteur="impala"; base="chu_dw";         options="" ;;
    *) echo "Configuration inconnue : $config" >&2; exit 1 ;;
  esac

  for fichier in "$DOSSIER_REQ"/*.sql; do
    requete="$(basename "$fichier" .sql)"
    # Liste restreinte si REQUETES est définie, sinon toutes les requêtes
    if [ -n "$REQUETES" ] && [[ " $REQUETES " != *" $requete "* ]]; then
      continue
    fi
    # Les variantes sur agrégats n'existent que dans chu_dw
    if [ "$base" != "chu_dw" ] && [[ "$requete" == *_agregat ]]; then
      continue
    fi
    for i in $(seq 1 "$NB_EXEC"); do
      resultat="$(executer "$moteur" "$base" "$options" "$fichier")"
      echo "$config;$moteur;$base;$requete;$i;$resultat" >> "$SORTIE"
      echo "[$config] $requete, exécution $i/$NB_EXEC : $resultat"
    done
  done
done

echo "Mesures : $SORTIE"
echo "Journal : $JOURNAL"

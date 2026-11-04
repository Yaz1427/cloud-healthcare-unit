#!/usr/bin/env bash
# =====================================================================
# explain.sh : enregistre les plans d'exécution de chaque requête de
#              bench/requetes/ sur chu_dw, avec les réglages « après ».
#
# À lancer DANS la VM Cloudera, depuis la racine du dépôt :
#   bash bench/explain.sh
#
# Pour chaque requête, resultats/benchmark/explain/<requete>.txt contient :
#   - EXPLAIN DEPENDENCY : les partitions réellement lues (élagage)
#   - EXPLAIN : le plan, dont le type de jointure, par exemple
#     « Map Join Operator » ou « Sorted Merge Bucket Map Join Operator »
# Ce sont les preuves à citer dans l'analyse du benchmark.
# =====================================================================
set -u

HOTE="${HOTE:-quickstart.cloudera}"
BASE="${BASE:-chu_dw}"
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
DOSSIER_EXP="$RACINE/resultats/benchmark/explain"
mkdir -p "$DOSSIER_EXP"

OPTIONS="--hiveconf hive.auto.convert.join=true \
--hiveconf hive.auto.convert.sortmerge.join=true \
--hiveconf hive.optimize.bucketmapjoin=true \
--hiveconf hive.optimize.bucketmapjoin.sortedmerge=true"

for fichier in "$RACINE"/bench/requetes/*.sql; do
  requete="$(basename "$fichier" .sql)"
  # Requête sur une seule ligne, sans les commentaires ni le point-virgule final
  corps="$(grep -v '^[[:space:]]*--' "$fichier" | tr '\n' ' ' | sed 's/;[[:space:]]*$//')"
  {
    echo "### $requete : EXPLAIN DEPENDENCY"
    beeline -u "jdbc:hive2://$HOTE:10000/$BASE" -n cloudera $OPTIONS \
      --outputformat=tsv2 -e "EXPLAIN DEPENDENCY $corps" 2> /dev/null
    echo
    echo "### $requete : EXPLAIN"
    beeline -u "jdbc:hive2://$HOTE:10000/$BASE" -n cloudera $OPTIONS \
      --outputformat=tsv2 -e "EXPLAIN $corps" 2> /dev/null
  } > "$DOSSIER_EXP/$requete.txt"
  echo "$requete : plan enregistré"
done

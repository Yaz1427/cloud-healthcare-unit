#!/usr/bin/env bash
# =====================================================================
# 02_depot_s3_s4.sh : dépôt dans HDFS des fichiers Silver S3, S4 et du
#                     référentiel des établissements enrichi
#
# Rôle    : copier dans HDFS les trois CSV produits par
#           restitution/01_extraction_s3_s4.sql. Chaque dossier Silver
#           concerné est vidé puis rechargé : le script est relançable.
# Machine : VM Cloudera, utilisateur cloudera
# Entrée  : un dossier local, par défaut /home/cloudera/chu_data, avec
#           deces.csv, satisfaction.csv et etablissement.csv
# Sortie  : /datalake/silver/deces/, /satisfaction/ et /etablissement/
#
# Lancement, depuis la racine du dépôt :
#   bash restitution/02_depot_s3_s4.sh /home/cloudera/chu_data 2>&1 | tee logs/08_depot_s3_s4.log
# =====================================================================
set -euo pipefail

DIR="${1:-/home/cloudera/chu_data}"
SILVER=/datalake/silver
TABLES="deces satisfaction etablissement"

[ -d "$DIR" ] || { echo "ERREUR : dossier $DIR introuvable"; exit 1; }

manque=0
for t in $TABLES; do
  if [ ! -s "$DIR/$t.csv" ]; then
    echo "ERREUR : $DIR/$t.csv absent ou vide"
    manque=1
  fi
done
[ "$manque" -eq 0 ] || exit 1

for t in $TABLES; do
  sed -i 's/\r$//' "$DIR/$t.csv"
  hdfs dfs -mkdir -p "$SILVER/$t"
  hdfs dfs -rm -r -f -skipTrash "$SILVER/$t/*" > /dev/null 2>&1 || true
  hdfs dfs -put -f "$DIR/$t.csv" "$SILVER/$t/$t.csv"
  echo "Silver $t : $(wc -l < "$DIR/$t.csv") lignes"
done

echo "Volumes dans HDFS :"
hdfs dfs -du -h "$SILVER/deces" "$SILVER/satisfaction" "$SILVER/etablissement"
echo "Dépôt terminé."

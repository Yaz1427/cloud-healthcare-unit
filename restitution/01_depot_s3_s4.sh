#!/usr/bin/env bash
# =====================================================================
# 01_depot_s3_s4.sh : dépôt dans HDFS des fichiers des lots S3 et S4
#
# Rôle    : - décès de l’INSEE, fichier brut avec en-tête, en Bronze
#           - établissements notés par e-Satis, en Bronze
#           - satisfaction e-Satis, déjà au format Silver
#           Les retours chariot Windows sont retirés au passage. Chaque
#           dossier est vidé puis rechargé : le script est relançable.
# Machine : VM Cloudera, utilisateur cloudera
# Entrée  : satisfaction.csv et esatis_etablissements.csv (produits par
#           convertir_esatis.py) dans /home/cloudera/chu_data par défaut,
#           deces.csv dans ce même dossier ou à l’endroit passé en argument
#           (à défaut, le script le cherche dans /home/cloudera)
# Sortie  : /datalake/bronze/deces/2019/, /datalake/bronze/esatis/2020/,
#           /datalake/silver/satisfaction/
#
# Lancement :
#   bash restitution/01_depot_s3_s4.sh [dossier] [chemin de deces.csv]
# =====================================================================
set -euo pipefail

DIR="${1:-/home/cloudera/chu_data}"
DECES="${2:-$DIR/deces.csv}"

if [ ! -s "$DECES" ]; then
  trouve="$(find /home/cloudera -maxdepth 4 -type f -name 'deces.csv' 2>/dev/null | head -1 || true)"
  [ -n "$trouve" ] || trouve="$(find /home/cloudera -maxdepth 4 -type f -iname 'deces*.csv' 2>/dev/null | head -1 || true)"
  [ -n "$trouve" ] || { echo "ERREUR : deces.csv introuvable, passer son chemin en 2e argument"; exit 1; }
  DECES="$trouve"
fi
for f in satisfaction.csv esatis_etablissements.csv; do
  [ -s "$DIR/$f" ] || { echo "ERREUR : $DIR/$f absent ou vide"; exit 1; }
done

echo "Décès    : $DECES, $(( $(wc -l < "$DECES") - 1 )) lignes hors en-tête"
echo "En-tête  : $(head -1 "$DECES" | sed -e '1s/^\xEF\xBB\xBF//' | tr -d '\r')"
echo "e-Satis  : $(wc -l < "$DIR/satisfaction.csv") établissements notés"

for d in /datalake/bronze/deces/2019 /datalake/bronze/esatis/2020 /datalake/silver/satisfaction; do
  hdfs dfs -mkdir -p "$d"
  hdfs dfs -rm -r -f -skipTrash "$d/*" > /dev/null 2>&1 || true
done

sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$DECES" | hdfs dfs -put - /datalake/bronze/deces/2019/deces.csv
sed 's/\r$//' "$DIR/esatis_etablissements.csv" | hdfs dfs -put - /datalake/bronze/esatis/2020/esatis_etablissements.csv
sed 's/\r$//' "$DIR/satisfaction.csv" | hdfs dfs -put - /datalake/silver/satisfaction/satisfaction.csv

hdfs dfs -du -h /datalake/bronze/deces/2019 /datalake/bronze/esatis/2020 /datalake/silver/satisfaction
echo "Dépôt terminé."

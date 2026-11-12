#!/usr/bin/env bash
# =====================================================================
# 00_lancer_s3_s4.sh : chargement des lots S3 (e-Satis 2020) et S4
#                      (décès 2019), puis nouvel export Power BI
#
# Enchaîne : 01 dépôt HDFS, 02 Silver (Hive), 03 Gold (Hive),
#            03 Impala (statistiques et contrôles), 04 export Power BI
# Machine  : VM Cloudera, Hive et Impala démarrés
# Durée    : de 20 min à 1 h selon la VM
#
# Lancement, depuis le dossier qui contient restitution/ :
#   bash restitution/00_lancer_s3_s4.sh 2>&1 | tee run_s3_s4.log
# Variables facultatives : DATA (dossier de satisfaction.csv et de
# esatis_etablissements.csv, par défaut donnees/ à côté de restitution/),
# DECES (chemin de deces.csv, cherché dans /home/cloudera s'il n'est pas
# dans DATA), HOTE (quickstart.cloudera)
# =====================================================================
set -euo pipefail

ICI="$(cd "$(dirname "$0")" && pwd)"
DATA="${DATA:-$(dirname "$ICI")/donnees}"
DECES="${DECES:-$DATA/deces.csv}"
HOTE="${HOTE:-quickstart.cloudera}"
# Mêmes réglages de mémoire que pour J20 et J21 au livrable 2
HIVE=(beeline -u "jdbc:hive2://$HOTE:10000" -n cloudera
      --hiveconf hive.mapred.local.mem=1024
      --hiveconf hive.mapjoin.smalltable.filesize=2000000
      --hiveconf hive.auto.convert.join.noconditionaltask.size=2000000
      --hiveconf mapreduce.map.memory.mb=2048
      --hiveconf mapreduce.map.java.opts=-Xmx1600m
      --hiveconf mapreduce.reduce.memory.mb=2048
      --hiveconf mapreduce.reduce.java.opts=-Xmx1600m)

etape() { echo; echo "===== $(date '+%H:%M:%S') : $*"; }

sed -i 's/\r$//' "$ICI"/*.sql "$ICI"/0[1-4]_*.sh

etape "0. Hive et Impala répondent-ils ?"
"${HIVE[@]}" -e "SHOW DATABASES" > /dev/null || { echo "ERREUR : Hive ne répond pas"; exit 1; }
impala-shell -i "$HOTE" -q "SELECT 1" > /dev/null 2>&1 || { echo "ERREUR : Impala ne répond pas"; exit 1; }

etape "1. Dépôt dans HDFS"
bash "$ICI/01_depot_s3_s4.sh" "$DATA" "$DECES"

etape "2. Silver : décès 2019 et établissements e-Satis (Hive)"
"${HIVE[@]}" -f "$ICI/02_silver_s3_s4.sql"

etape "3. Gold : dim_etablissement, fait_deces, fait_satisfaction (Hive)"
"${HIVE[@]}" -f "$ICI/03_gold_s3_s4.sql"

etape "3 bis. Impala : métadonnées, statistiques et contrôles"
impala-shell -i "$HOTE" -f "$ICI/03_gold_s3_s4_impala.sql"

etape "4. Export Power BI"
bash "$ICI/04_export_powerbi.sh"

etape "Terminé : envoyer la fin de ce journal à Tilal, et l’archive par le Drive privé"

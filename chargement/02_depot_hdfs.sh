#!/usr/bin/env bash
# =====================================================================
# 02_depot_hdfs.sh : dépôt des fichiers Silver et des référentiels dans HDFS
#
# Rôle    : copier dans HDFS les CSV produits par 01_extraction_s1.sql,
#           les fichiers du COG s'ils sont fournis, et le fichier brut des
#           hospitalisations dans Bronze (copie datée) s'il est fourni.
# Machine : VM Cloudera, utilisateur cloudera
# Entrée  : un dossier local, par défaut /home/cloudera/chu_data
# Sortie  : /datalake/silver/<table>/, /datalake/referentiels/cog_insee/,
#           /datalake/bronze/s1_hospitalisation/<date>/
#
# Lancement, depuis la racine du dépôt :
#   bash chargement/02_depot_hdfs.sh /home/cloudera/chu_data 2>&1 | tee logs/05_depot_hdfs.log
# Relançable : chaque dossier Silver est vidé puis rechargé.
# =====================================================================
set -euo pipefail

DIR="${1:-/home/cloudera/chu_data}"
JOUR="$(date +%Y-%m-%d)"
SILVER=/datalake/silver
COG=/datalake/referentiels/cog_insee
TABLES="patient professionnel diagnostic consultation hospitalisation etablissement"

[ -d "$DIR" ] || { echo "ERREUR : dossier $DIR introuvable"; exit 1; }

# Les six fichiers de 01_extraction_s1.sql sont obligatoires
manque=0
for t in $TABLES; do
  if [ ! -s "$DIR/$t.csv" ]; then
    echo "ERREUR : $DIR/$t.csv absent ou vide"
    manque=1
  fi
done
[ "$manque" -eq 0 ] || exit 1

# Dossiers HDFS. On les donne à cloudera (sudo sans mot de passe dans la
# QuickStart) au cas où Hive les aurait créés sous un autre utilisateur.
sudo -n -u hdfs hdfs dfs -mkdir -p "$SILVER" /datalake/bronze /datalake/referentiels 2>/dev/null || true
sudo -n -u hdfs hdfs dfs -chown -R cloudera:cloudera "$SILVER" /datalake/bronze /datalake/referentiels 2>/dev/null || true
hdfs dfs -mkdir -p "$SILVER" /datalake/bronze "$COG"

# Silver : fins de ligne Windows retirées, dossier vidé puis rechargé
for t in $TABLES; do
  sed -i 's/\r$//' "$DIR/$t.csv"
  hdfs dfs -mkdir -p "$SILVER/$t"
  hdfs dfs -rm -r -f -skipTrash "$SILVER/$t/*" > /dev/null 2>&1 || true
  hdfs dfs -put -f "$DIR/$t.csv" "$SILVER/$t/$t.csv"
  echo "Silver $t : $(wc -l < "$DIR/$t.csv") lignes"
done

# Satisfaction et décès ne sont pas chargés ce soir : dossiers vides
hdfs dfs -mkdir -p "$SILVER/satisfaction" "$SILVER/deces"

# COG : rechargé seulement si les fichiers sont fournis
for r in departement region; do
  if [ -s "$DIR/ref_$r.csv" ]; then
    sed -i 's/\r$//' "$DIR/ref_$r.csv"
    hdfs dfs -mkdir -p "$COG/$r"
    hdfs dfs -rm -r -f -skipTrash "$COG/$r/*" > /dev/null 2>&1 || true
    hdfs dfs -put -f "$DIR/ref_$r.csv" "$COG/$r/ref_$r.csv"
    echo "COG $r : $(wc -l < "$DIR/ref_$r.csv") lignes, en-tête compris"
  elif hdfs dfs -test -d "$COG/$r" && [ -n "$(hdfs dfs -ls "$COG/$r" 2>/dev/null | grep -v '^Found')" ]; then
    echo "COG $r : déjà présent dans HDFS, conservé"
  else
    echo "ATTENTION : COG $r absent. Mets ref_$r.csv dans $DIR et relance."
  fi
done

# Bronze : copie brute et datée du fichier des hospitalisations, si fourni
if [ -s "$DIR/Hospitalisations.csv" ]; then
  hdfs dfs -mkdir -p "/datalake/bronze/s1_hospitalisation/$JOUR"
  hdfs dfs -put -f "$DIR/Hospitalisations.csv" "/datalake/bronze/s1_hospitalisation/$JOUR/"
  echo "Bronze : Hospitalisations.csv copié dans /datalake/bronze/s1_hospitalisation/$JOUR"
fi

echo "Volumes dans HDFS :"
hdfs dfs -du -h "$SILVER" "$COG"
echo "Dépôt terminé."

#!/usr/bin/env bash
# =====================================================================
# 04_export_powerbi.sh : export de la Gold pour Power BI, mode Import
#
# Rôle    : écrire chaque table de chu_dw dans un fichier texte tabulé,
#           avec une ligne d'en-tête, pour construire le tableau de bord
#           sur un poste sans la VM. Ce sont les tables que le connecteur
#           Impala importerait, avec deux réductions :
#           - pas de patient_pseudo ni de numéro d'acte : inutiles aux
#             indicateurs (minimisation, règle R10) ;
#           - fait_deces agrégé par mois, région, sexe et âge : même
#             mesure nb_deces, des centaines de milliers de lignes en moins.
# Machine : VM Cloudera, après sql/06_j22_impala_refresh.sql
# Entrée  : base chu_dw
# Sortie  : un dossier, par défaut /home/cloudera/export_powerbi, avec un
#           fichier .tsv par table et export_powerbi.tar.gz
#
# Lancement, depuis la racine du dépôt :
#   bash restitution/04_export_powerbi.sh 2>&1 | tee logs/09_export_powerbi.log
#
# Les fichiers contiennent des données pseudonymisées (clés de
# substitution, âge, sexe, département) : ils restent sur les postes du
# groupe, par clé USB ou dossier partagé privé, jamais dans Git ni sur
# un canal public.
# =====================================================================
set -euo pipefail

SORTIE="${1:-/home/cloudera/export_powerbi}"
HOTE="${HOTE:-quickstart.cloudera}"
mkdir -p "$SORTIE"
rm -f "$SORTIE"/*.tsv "$SORTIE/export_powerbi.tar.gz"

# Une table : requête Impala, sortie tabulée avec en-tête, comptage
exporter() {
  local nom="$1" requete="$2"
  impala-shell -i "$HOTE" -d chu_dw -B --print_header -q "$requete" \
    -o "$SORTIE/$nom.tsv" 2>> "$SORTIE/export.log"
  echo "$nom : $(( $(wc -l < "$SORTIE/$nom.tsv") - 1 )) lignes"
}

exporter dim_temps \
  "SELECT id_temps, date_complete, jour, mois, libelle_mois, trimestre, annee, jour_semaine FROM dim_temps"
exporter dim_patient \
  "SELECT id_patient, sexe, annee_naissance, code_departement FROM dim_patient"
exporter dim_professionnel \
  "SELECT id_professionnel, identifiant_source, profession, specialite, categorie FROM dim_professionnel"
exporter dim_diagnostic \
  "SELECT id_diagnostic, code_diagnostic, libelle_diagnostic FROM dim_diagnostic"
exporter dim_etablissement \
  "SELECT id_etablissement, finess, raison_sociale, commune, code_departement, code_region, nom_region FROM dim_etablissement"
exporter dim_region \
  "SELECT id_region, code_region, nom_region FROM dim_region"
exporter fait_consultation \
  "SELECT id_temps, id_patient, id_professionnel, id_diagnostic, id_etablissement, age_patient, nb_consultation, annee FROM fait_consultation"
exporter fait_hospitalisation \
  "SELECT id_temps, id_patient, id_diagnostic, id_etablissement, age_patient, duree_sejour, nb_hospitalisation, annee FROM fait_hospitalisation"
exporter fait_deces \
  "SELECT (id_temps DIV 100) * 100 + 1 AS id_temps, id_region, sexe, age_deces, SUM(nb_deces) AS nb_deces, annee FROM fait_deces GROUP BY (id_temps DIV 100) * 100 + 1, id_region, sexe, age_deces, annee"
exporter fait_satisfaction \
  "SELECT id_temps, id_etablissement, score_global, nb_repondants, annee FROM fait_satisfaction"

# Contrôle : le total des décès agrégés doit égaler le nombre de lignes de fait_deces
impala-shell -i "$HOTE" -d chu_dw -B -q \
  "SELECT annee, COUNT(*) FROM fait_deces GROUP BY annee ORDER BY annee" 2>> "$SORTIE/export.log" \
  | sed 's/^/Décès en Gold, par année : /'

cd "$SORTIE"
tar -czf export_powerbi.tar.gz ./*.tsv
echo "Archive : $SORTIE/export_powerbi.tar.gz ($(du -h export_powerbi.tar.gz | cut -f1))"

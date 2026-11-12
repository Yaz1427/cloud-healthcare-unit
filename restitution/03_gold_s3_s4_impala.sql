-- =====================================================================
-- 03_gold_s3_s4_impala.sql : Impala voit les trois tables rechargées par Hive
--
-- Rôle    : recharger les métadonnées et les statistiques des tables
--           écrites par 03_gold_s3_s4.sql, puis afficher les contrôles
--           du lot (ils servent au tableau de bord et à la soutenance)
-- Job     : J22, limité aux trois tables du lot S3 et S4
-- Moteur  : Impala 2.9, par impala-shell
-- Lancement : impala-shell -i quickstart.cloudera -f restitution/03_gold_s3_s4_impala.sql
-- =====================================================================

INVALIDATE METADATA chu_dw.dim_etablissement;
INVALIDATE METADATA chu_dw.fait_deces;
INVALIDATE METADATA chu_dw.fait_satisfaction;
COMPUTE STATS chu_dw.dim_etablissement;
COMPUTE STATS chu_dw.fait_deces;
COMPUTE STATS chu_dw.fait_satisfaction;

-- Établissements : 2472 avant le lot, plus les établissements e-Satis ajoutés
SELECT COUNT(*) AS nb_etablissements,
       SUM(CASE WHEN id_etablissement = -1 THEN 1 ELSE 0 END) AS membre_inconnu,
       COUNT(DISTINCT finess) AS finess_distincts
FROM chu_dw.dim_etablissement;

-- Décès : une ligne par décès
SELECT annee, COUNT(*) AS nb_lignes, SUM(nb_deces) AS nb_deces,
       SUM(CASE WHEN id_region = -1 THEN nb_deces ELSE 0 END) AS region_inconnue,
       SUM(CASE WHEN age_deces IS NULL THEN nb_deces ELSE 0 END) AS age_inconnu
FROM chu_dw.fait_deces
GROUP BY annee
ORDER BY annee;

SELECT r.nom_region, SUM(f.nb_deces) AS nb_deces
FROM chu_dw.fait_deces f
JOIN chu_dw.dim_region r ON r.id_region = f.id_region
GROUP BY r.nom_region
ORDER BY nb_deces DESC;

-- Satisfaction : un établissement noté par année, aucun sans établissement
SELECT annee, COUNT(*) AS etablissements_notes,
       SUM(CASE WHEN id_etablissement = -1 THEN 1 ELSE 0 END) AS sans_etablissement,
       ROUND(AVG(score_global), 2) AS score_moyen,
       SUM(nb_repondants) AS nb_repondants
FROM chu_dw.fait_satisfaction
GROUP BY annee;

-- =====================================================================
-- 05_agregats_stats.sql : agrégats mensuels et statistiques (fin de J21)
--
-- Rôle    : recalculer les tables d’agrégats, puis les statistiques de
--           toutes les tables de chu_dw.
-- Entrée  : faits et dimensions de chu_dw (sql/03 et sql/04 exécutés)
-- Sortie  : agg_consultation_mois, agg_hospitalisation_mois, statistiques
--           du metastore (lignes, fichiers, taille)
-- Moteur  : Hive 1.1
--
-- Les agrégats remplacent les vues matérialisées, absentes de Hive 1.1.
-- Ils ne contiennent que des comptages additifs : un nombre de patients
-- distincts ne s’additionne pas d’un mois à l’autre, le KPI 3 reste donc
-- calculé sur les faits.
-- Premier chargement : toutes les années. Ensuite, filtrer sur les
-- années rechargées, par exemple  WHERE f.annee IN (2023, 2024)
--
-- Facultatif, pour l’essai de l’optimiseur par les coûts (CBO, désactivé
-- par défaut sur CDH) : statistiques de colonnes, à lancer à la main et à
-- garder seulement si le benchmark montre un gain avec hive.cbo.enable
--   ANALYZE TABLE fait_consultation PARTITION (annee) COMPUTE STATISTICS FOR COLUMNS
--   ANALYZE TABLE fait_hospitalisation PARTITION (annee) COMPUTE STATISTICS FOR COLUMNS
-- =====================================================================

USE chu_dw;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.auto.convert.join=true;
SET parquet.compression=SNAPPY;

-- ---------------------------------------------------------------------
-- Consultations par mois, établissement, diagnostic et professionnel
-- (KPI 1, 2 et 6)
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE agg_consultation_mois PARTITION (annee)
SELECT t.mois, f.id_etablissement, f.id_diagnostic, f.id_professionnel,
       SUM(f.nb_consultation) AS nb_consultation,
       f.annee
FROM fait_consultation f
JOIN dim_temps t ON f.id_temps = t.id_temps
GROUP BY f.annee, t.mois, f.id_etablissement, f.id_diagnostic, f.id_professionnel;

-- ---------------------------------------------------------------------
-- Séjours par mois, établissement, diagnostic, sexe et tranche d’âge
-- (KPI 4 et 5, durée moyenne de séjour)
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE agg_hospitalisation_mois PARTITION (annee)
SELECT y.mois, y.id_etablissement, y.id_diagnostic, y.sexe, y.tranche_age,
       SUM(y.nb_hospitalisation) AS nb_hospitalisation,
       SUM(y.duree_sejour)       AS nb_jours,
       y.annee
FROM (SELECT t.mois, h.id_etablissement, h.id_diagnostic,
             COALESCE(p.sexe, 'I') AS sexe,
             CASE WHEN h.age_patient IS NULL THEN 'inconnu'
                  WHEN h.age_patient < 18 THEN '0-17'
                  WHEN h.age_patient < 40 THEN '18-39'
                  WHEN h.age_patient < 60 THEN '40-59'
                  WHEN h.age_patient < 75 THEN '60-74'
                  ELSE '75+' END AS tranche_age,
             h.nb_hospitalisation, h.duree_sejour, h.annee
      FROM fait_hospitalisation h
      JOIN dim_temps t ON h.id_temps = t.id_temps
      LEFT OUTER JOIN dim_patient p ON h.id_patient = p.id_patient) y
GROUP BY y.annee, y.mois, y.id_etablissement, y.id_diagnostic, y.sexe, y.tranche_age;

-- ---------------------------------------------------------------------
-- Statistiques de base (lignes, fichiers, taille) : elles guident les
-- choix de jointure de Hive. Les tables partitionnées sont analysées
-- partition par partition.
-- ---------------------------------------------------------------------
ANALYZE TABLE dim_temps COMPUTE STATISTICS;
ANALYZE TABLE dim_patient COMPUTE STATISTICS;
ANALYZE TABLE dim_professionnel COMPUTE STATISTICS;
ANALYZE TABLE dim_diagnostic COMPUTE STATISTICS;
ANALYZE TABLE dim_etablissement COMPUTE STATISTICS;
ANALYZE TABLE dim_region COMPUTE STATISTICS;
ANALYZE TABLE fait_consultation PARTITION (annee) COMPUTE STATISTICS;
ANALYZE TABLE fait_hospitalisation PARTITION (annee) COMPUTE STATISTICS;
ANALYZE TABLE fait_deces PARTITION (annee) COMPUTE STATISTICS;
ANALYZE TABLE fait_satisfaction PARTITION (annee) COMPUTE STATISTICS;
ANALYZE TABLE agg_consultation_mois PARTITION (annee) COMPUTE STATISTICS;
ANALYZE TABLE agg_hospitalisation_mois PARTITION (annee) COMPUTE STATISTICS;

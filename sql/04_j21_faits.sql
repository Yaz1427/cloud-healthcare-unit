-- =====================================================================
-- 04_j21_faits.sql : chargement des tables de faits (job J21)
--
-- Rôle    : alimenter les 4 tables de faits de chu_dw.
-- Entrée  : chu_silver et les dimensions de chu_dw (sql/03 exécuté avant)
-- Sortie  : fait_consultation, fait_hospitalisation, fait_deces,
--           fait_satisfaction, partitionnées par année
-- Moteur  : Hive 1.1. Dans Talend : une instruction par tHiveRow.
--
-- Intégrité référentielle : chaque clé étrangère est retrouvée par
-- jointure externe sur la clé métier, et une ligne sans correspondance
-- est rattachée au membre -1 (R4). Aucun fait n’est perdu et aucun ne
-- pointe vers une ligne absente de sa dimension.
--
-- Partitions dynamiques : la colonne annee vient en dernier dans le
-- SELECT. INSERT OVERWRITE ne remplace que les années présentes dans le
-- résultat, les autres partitions restent intactes.
--
-- Premier chargement : toutes les années (pas de filtre).
-- Chargements trimestriels, ou si un chargement manque de mémoire :
-- ajouter un filtre sur l’année à la fin de chaque requête, par exemple
--   WHERE YEAR(c.date_consultation) IN (2023, 2024)
-- =====================================================================

USE chu_dw;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.enforce.bucketing=true;
SET hive.enforce.sorting=true;
SET hive.auto.convert.join=true;
SET parquet.compression=SNAPPY;

-- ---------------------------------------------------------------------
-- fait_consultation : grain une consultation
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_consultation PARTITION (annee)
SELECT c.id_consultation,
       CAST(regexp_replace(CAST(c.date_consultation AS STRING), '-', '') AS INT)
                                         AS id_temps,
       COALESCE(p.id_patient, -1)        AS id_patient,
       COALESCE(pr.id_professionnel, -1) AS id_professionnel,
       COALESCE(dg.id_diagnostic, -1)    AS id_diagnostic,
       COALESCE(e.id_etablissement, -1)  AS id_etablissement,
       c.age_patient,
       1                                 AS nb_consultation,
       YEAR(c.date_consultation)         AS annee
FROM chu_silver.consultation c
LEFT OUTER JOIN dim_patient p        ON p.patient_pseudo = c.patient_pseudo
LEFT OUTER JOIN dim_professionnel pr ON pr.identifiant_source = c.identifiant_professionnel
LEFT OUTER JOIN dim_diagnostic dg    ON dg.code_diagnostic = c.code_diagnostic
LEFT OUTER JOIN dim_etablissement e  ON e.finess = c.finess;

-- ---------------------------------------------------------------------
-- fait_hospitalisation : grain un séjour, rangé dans l’année d’entrée
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_hospitalisation PARTITION (annee)
SELECT h.id_hospitalisation,
       CAST(regexp_replace(CAST(h.date_entree AS STRING), '-', '') AS INT)
                                        AS id_temps,
       COALESCE(p.id_patient, -1)       AS id_patient,
       COALESCE(dg.id_diagnostic, -1)   AS id_diagnostic,
       COALESCE(e.id_etablissement, -1) AS id_etablissement,
       h.age_patient,
       h.duree_sejour,
       1                                AS nb_hospitalisation,
       YEAR(h.date_entree)              AS annee
FROM chu_silver.hospitalisation h
LEFT OUTER JOIN dim_patient p       ON p.patient_pseudo = h.patient_pseudo
LEFT OUTER JOIN dim_diagnostic dg   ON dg.code_diagnostic = h.code_diagnostic
LEFT OUTER JOIN dim_etablissement e ON e.finess = h.finess;

-- ---------------------------------------------------------------------
-- fait_deces : grain un décès, région du lieu de décès via le COG
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_deces PARTITION (annee)
SELECT CAST(regexp_replace(CAST(d.date_deces AS STRING), '-', '') AS INT)
                                 AS id_temps,
       COALESCE(r.id_region, -1) AS id_region,
       d.sexe,
       d.age_deces,
       1                         AS nb_deces,
       YEAR(d.date_deces)        AS annee
FROM chu_silver.deces d
LEFT OUTER JOIN chu_silver.ref_departement rd ON rd.code_departement = d.code_departement
LEFT OUTER JOIN dim_region r                  ON r.code_region = rd.code_region;

-- ---------------------------------------------------------------------
-- fait_satisfaction : grain un établissement par année de recueil,
-- daté du 1er janvier de cette année (AAAA0101)
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_satisfaction PARTITION (annee)
SELECT s.annee_recueil * 10000 + 101    AS id_temps,
       COALESCE(e.id_etablissement, -1) AS id_etablissement,
       s.score_global,
       s.nb_repondants,
       s.annee_recueil                  AS annee
FROM chu_silver.satisfaction s
LEFT OUTER JOIN dim_etablissement e ON e.finess = s.finess;

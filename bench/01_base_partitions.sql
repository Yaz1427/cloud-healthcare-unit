-- =====================================================================
-- 01_base_partitions.sql : base intermédiaire du benchmark (chu_bench_part)
--
-- Rôle    : isoler l’effet du partitionnement. Mêmes données que chu_dw,
--           en texte brut, faits partitionnés par année, mais sans
--           bucket, sans Parquet et sans statistiques.
--           Comparer avant, puis partitions seules, puis chu_dw sépare
--           l’effet des partitions de celui des autres leviers (buckets
--           triés, Parquet, statistiques), comme le demande le sujet.
-- Entrée  : chu_dw chargée (sql/02 à sql/05)
-- Sortie  : base chu_bench_part
-- Moteur  : Hive 1.1
-- Statut  : facultatif, à lancer si le temps le permet
-- =====================================================================

CREATE DATABASE IF NOT EXISTS chu_bench_part
COMMENT 'Benchmark : partitions seules, texte brut, sans bucket';
USE chu_bench_part;
SET hive.stats.autogather=false;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- ---------------------------------------------------------------------
-- Dimensions : simples copies en texte brut
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_temps;
CREATE TABLE dim_temps STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_temps;

DROP TABLE IF EXISTS dim_patient;
CREATE TABLE dim_patient STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_patient;

DROP TABLE IF EXISTS dim_professionnel;
CREATE TABLE dim_professionnel STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_professionnel;

DROP TABLE IF EXISTS dim_diagnostic;
CREATE TABLE dim_diagnostic STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_diagnostic;

DROP TABLE IF EXISTS dim_etablissement;
CREATE TABLE dim_etablissement STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_etablissement;

DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region STORED AS TEXTFILE
AS SELECT * FROM chu_dw.dim_region;

-- ---------------------------------------------------------------------
-- Faits : partitionnés par année, sans bucket
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fait_consultation;
CREATE TABLE fait_consultation (
  id_consultation  STRING,
  id_temps         INT,
  id_patient       INT,
  id_professionnel INT,
  id_diagnostic    INT,
  id_etablissement INT,
  age_patient      INT,
  nb_consultation  INT
)
PARTITIONED BY (annee INT)
STORED AS TEXTFILE;
INSERT OVERWRITE TABLE fait_consultation PARTITION (annee)
SELECT * FROM chu_dw.fait_consultation;

DROP TABLE IF EXISTS fait_hospitalisation;
CREATE TABLE fait_hospitalisation (
  id_hospitalisation STRING,
  id_temps           INT,
  id_patient         INT,
  id_diagnostic      INT,
  id_etablissement   INT,
  age_patient        INT,
  duree_sejour       INT,
  nb_hospitalisation INT
)
PARTITIONED BY (annee INT)
STORED AS TEXTFILE;
INSERT OVERWRITE TABLE fait_hospitalisation PARTITION (annee)
SELECT * FROM chu_dw.fait_hospitalisation;

DROP TABLE IF EXISTS fait_deces;
CREATE TABLE fait_deces (
  id_temps  INT,
  id_region INT,
  sexe      STRING,
  age_deces INT,
  nb_deces  INT
)
PARTITIONED BY (annee INT)
STORED AS TEXTFILE;
INSERT OVERWRITE TABLE fait_deces PARTITION (annee)
SELECT * FROM chu_dw.fait_deces;

DROP TABLE IF EXISTS fait_satisfaction;
CREATE TABLE fait_satisfaction (
  id_temps         INT,
  id_etablissement INT,
  score_global     DOUBLE,
  nb_repondants    INT
)
PARTITIONED BY (annee INT)
STORED AS TEXTFILE;
INSERT OVERWRITE TABLE fait_satisfaction PARTITION (annee)
SELECT * FROM chu_dw.fait_satisfaction;

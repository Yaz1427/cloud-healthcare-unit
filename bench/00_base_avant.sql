-- =====================================================================
-- 00_base_avant.sql : base « avant » du benchmark (chu_bench_brut)
--
-- Rôle    : copier les tables de chu_dw sans aucune optimisation, en
--           texte brut, sans partition, sans bucket et sans statistiques.
--           annee y devient une colonne ordinaire : les requêtes de
--           bench/requetes/ tournent sans modification, mais Hive lit
--           toute la table au lieu d’une seule partition.
-- Entrée  : chu_dw chargée (sql/02 à sql/05)
-- Sortie  : base chu_bench_brut, mêmes données que chu_dw
-- Moteur  : Hive 1.1
-- =====================================================================

CREATE DATABASE IF NOT EXISTS chu_bench_brut
COMMENT 'Benchmark : copie de chu_dw sans optimisation';
USE chu_bench_brut;
SET hive.stats.autogather=false;

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

DROP TABLE IF EXISTS fait_consultation;
CREATE TABLE fait_consultation STORED AS TEXTFILE
AS SELECT * FROM chu_dw.fait_consultation;

DROP TABLE IF EXISTS fait_hospitalisation;
CREATE TABLE fait_hospitalisation STORED AS TEXTFILE
AS SELECT * FROM chu_dw.fait_hospitalisation;

DROP TABLE IF EXISTS fait_deces;
CREATE TABLE fait_deces STORED AS TEXTFILE
AS SELECT * FROM chu_dw.fait_deces;

DROP TABLE IF EXISTS fait_satisfaction;
CREATE TABLE fait_satisfaction STORED AS TEXTFILE
AS SELECT * FROM chu_dw.fait_satisfaction;

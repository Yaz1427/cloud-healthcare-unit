-- =====================================================================
-- 00_base_avant_impala.sql : base chu_bench_brut construite par Impala
--
-- Role    : meme resultat que bench/00_base_avant.sql (copie de chu_dw en
--           texte brut, sans partition, sans bucket, sans statistiques),
--           mais en quelques secondes au lieu de 10 a 20 minutes de Hive.
-- Moteur  : Impala 2.9, apres sql/06_j22_impala_refresh.sql
-- Entree  : base chu_dw
-- Sortie  : base chu_bench_brut, lue par la configuration avant (Hive)
--
-- Lancement :
--   impala-shell -i quickstart.cloudera -f bench/00_base_avant_impala.sql
-- Le moteur qui ecrit la copie ne change rien a la mesure : la
-- configuration avant lit ces fichiers texte avec Hive, sans statistiques.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS chu_bench_brut
COMMENT 'Benchmark : copie de chu_dw sans optimisation';

USE chu_bench_brut;

DROP TABLE IF EXISTS dim_temps;
CREATE TABLE dim_temps STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_temps;

DROP TABLE IF EXISTS dim_patient;
CREATE TABLE dim_patient STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_patient;

DROP TABLE IF EXISTS dim_professionnel;
CREATE TABLE dim_professionnel STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_professionnel;

DROP TABLE IF EXISTS dim_diagnostic;
CREATE TABLE dim_diagnostic STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_diagnostic;

DROP TABLE IF EXISTS dim_etablissement;
CREATE TABLE dim_etablissement STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_etablissement;

DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region STORED AS TEXTFILE AS SELECT * FROM chu_dw.dim_region;

DROP TABLE IF EXISTS fait_consultation;
CREATE TABLE fait_consultation STORED AS TEXTFILE AS SELECT * FROM chu_dw.fait_consultation;

DROP TABLE IF EXISTS fait_hospitalisation;
CREATE TABLE fait_hospitalisation STORED AS TEXTFILE AS SELECT * FROM chu_dw.fait_hospitalisation;

DROP TABLE IF EXISTS fait_deces;
CREATE TABLE fait_deces STORED AS TEXTFILE AS SELECT * FROM chu_dw.fait_deces;

DROP TABLE IF EXISTS fait_satisfaction;
CREATE TABLE fait_satisfaction STORED AS TEXTFILE AS SELECT * FROM chu_dw.fait_satisfaction;

SELECT 'fait_consultation' AS t, COUNT(*) AS n FROM fait_consultation
UNION ALL SELECT 'fait_hospitalisation', COUNT(*) FROM fait_hospitalisation;

-- =====================================================================
-- 00_bases.sql : bases Hive du lakehouse
--
-- Rôle    : créer une base par couche du lakehouse.
-- Moteur  : Hive 1.1 (CDH 5.12), dans Beeline ou dans l’éditeur Hive de Hue
-- Ordre   : avant tous les autres scripts
-- =====================================================================

-- Bronze : tables externes de profilage, posées au besoin sur les fichiers bruts
CREATE DATABASE IF NOT EXISTS chu_bronze
COMMENT 'Couche Bronze : fichiers bruts dates, profilage uniquement';

-- Silver : tables externes sur les fichiers nettoyés et pseudonymisés par Talend
CREATE DATABASE IF NOT EXISTS chu_silver
COMMENT 'Couche Silver : donnees nettoyees et pseudonymisees';

-- Gold : entrepôt décisionnel, constellation et agrégats
CREATE DATABASE IF NOT EXISTS chu_dw
COMMENT 'Couche Gold : entrepot decisionnel du CHU';

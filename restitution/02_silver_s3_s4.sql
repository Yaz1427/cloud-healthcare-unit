-- =====================================================================
-- 02_silver_s3_s4.sql : décès INSEE (S4) et établissements e-Satis (S3) en Silver
--
-- Rôle    : 1) lire le fichier brut de l’INSEE déposé en Bronze et écrire
--              chu_silver.deces sans aucune donnée nominative (R10) :
--              sexe M, F ou I (R2), date de décès ramenée au 1er janvier
--              si elle est partielle (R12), âge NULL si la date de naissance
--              est partielle ou l’âge hors de 0 à 130 ans, département du
--              lieu de décès, 97x pour l’outre-mer (R6). Année gardée : 2019
--           2) ajouter à chu_silver.etablissement les établissements notés
--              par e-Satis qui n’y sont pas encore. Relançable : au second
--              passage, aucun établissement n’est ajouté
-- Job     : J13 (décès) et J12 (établissements)
-- Moteur  : Hive 1.1, par Beeline (les tables Silver sont en TEXTFILE avec
--           des colonnes DATE, écrites par Hive et non par Impala)
-- Entrée  : /datalake/bronze/deces/2019/ et /datalake/bronze/esatis/2020/,
--           déposés par 01_depot_s3_s4.sh
-- Sortie  : chu_silver.deces, chu_silver.etablissement
-- =====================================================================

CREATE DATABASE IF NOT EXISTS chu_bronze;
SET hive.exec.compress.output=false;

CREATE EXTERNAL TABLE IF NOT EXISTS chu_silver.deces (
  sexe             STRING,
  date_deces       DATE,
  age_deces        INT,
  code_departement STRING,
  date_chargement  DATE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/deces';

CREATE EXTERNAL TABLE IF NOT EXISTS chu_silver.satisfaction (
  finess          STRING,
  annee_recueil   INT,
  score_global    DOUBLE,
  nb_repondants   INT,
  date_chargement DATE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/satisfaction';

-- Fichier brut de l’INSEE : virgule et guillemets doubles, valeurs par
-- défaut de la SerDe CSV, ligne d’en-tête ignorée
DROP TABLE IF EXISTS chu_bronze.deces_insee;
CREATE EXTERNAL TABLE chu_bronze.deces_insee (
  nom                 STRING,
  prenom              STRING,
  sexe                STRING,
  date_naissance      STRING,
  code_lieu_naissance STRING,
  lieu_naissance      STRING,
  pays_naissance      STRING,
  date_deces          STRING,
  code_lieu_deces     STRING,
  numero_acte_deces   STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
STORED AS TEXTFILE
LOCATION '/datalake/bronze/deces/2019'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Dates ramenées à AAAAMMJJ (formats AAAAMMJJ, AAAA-MM-JJ ou JJ/MM/AAAA),
-- puis règles R2, R6, R10 et R12
INSERT OVERWRITE TABLE chu_silver.deces
SELECT v.sexe, v.date_deces, v.age_deces, v.code_departement, v.date_chargement
FROM (
  SELECT CASE WHEN n.sexe IN ('1', 'M') THEN 'M'
              WHEN n.sexe IN ('2', 'F') THEN 'F'
              ELSE 'I' END AS sexe,
         CAST(CASE WHEN substr(n.dd, 5, 2) = '00' OR substr(n.dd, 7, 2) = '00'
                   THEN concat(substr(n.dd, 1, 4), '-01-01')
                   ELSE concat(substr(n.dd, 1, 4), '-', substr(n.dd, 5, 2), '-', substr(n.dd, 7, 2))
              END AS DATE) AS date_deces,
         CASE WHEN n.dn IS NULL
                   OR substr(n.dn, 5, 2) = '00' OR substr(n.dn, 7, 2) = '00'
                   OR substr(n.dd, 5, 2) = '00' OR substr(n.dd, 7, 2) = '00'
              THEN CAST(NULL AS INT)
              WHEN (CAST(substr(n.dd, 1, 4) AS INT) - CAST(substr(n.dn, 1, 4) AS INT)
                    - CASE WHEN substr(n.dd, 5, 4) < substr(n.dn, 5, 4) THEN 1 ELSE 0 END)
                   BETWEEN 0 AND 130
              THEN CAST(substr(n.dd, 1, 4) AS INT) - CAST(substr(n.dn, 1, 4) AS INT)
                   - CASE WHEN substr(n.dd, 5, 4) < substr(n.dn, 5, 4) THEN 1 ELSE 0 END
              ELSE CAST(NULL AS INT) END AS age_deces,
         CASE WHEN substr(n.lieu, 1, 2) = '97' THEN substr(n.lieu, 1, 3)
              ELSE substr(n.lieu, 1, 2) END AS code_departement,
         CAST(to_date(from_unixtime(unix_timestamp())) AS DATE) AS date_chargement
  FROM (
    SELECT upper(trim(b.sexe)) AS sexe,
           CASE WHEN trim(b.date_deces) RLIKE '^[0-9]{8}$' THEN trim(b.date_deces)
                WHEN trim(b.date_deces) RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                  THEN regexp_replace(trim(b.date_deces), '-', '')
                WHEN trim(b.date_deces) RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                  THEN concat(substr(trim(b.date_deces), 7, 4), substr(trim(b.date_deces), 4, 2),
                              substr(trim(b.date_deces), 1, 2))
                ELSE NULL END AS dd,
           CASE WHEN trim(b.date_naissance) RLIKE '^[0-9]{8}$' THEN trim(b.date_naissance)
                WHEN trim(b.date_naissance) RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                  THEN regexp_replace(trim(b.date_naissance), '-', '')
                WHEN trim(b.date_naissance) RLIKE '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                  THEN concat(substr(trim(b.date_naissance), 7, 4), substr(trim(b.date_naissance), 4, 2),
                              substr(trim(b.date_naissance), 1, 2))
                ELSE NULL END AS dn,
           CASE WHEN length(trim(b.code_lieu_deces)) = 4 THEN concat('0', trim(b.code_lieu_deces))
                ELSE upper(trim(b.code_lieu_deces)) END AS lieu
    FROM chu_bronze.deces_insee b
  ) n
  WHERE n.dd IS NOT NULL AND substr(n.dd, 1, 4) = '2019'
) v
WHERE v.date_deces IS NOT NULL;

-- Établissements e-Satis notés, au format de chu_silver.etablissement
DROP TABLE IF EXISTS chu_bronze.esatis_etablissement;
CREATE EXTERNAL TABLE chu_bronze.esatis_etablissement (
  finess             STRING,
  raison_sociale     STRING,
  commune            STRING,
  code_commune_insee STRING,
  code_departement   STRING,
  date_chargement    DATE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/bronze/esatis/2020';

-- Seuls ceux qui manquent sont ajoutés : un FINESS reste unique en Silver
DROP TABLE IF EXISTS chu_bronze.esatis_etab_nouveaux;
CREATE TABLE chu_bronze.esatis_etab_nouveaux AS
SELECT b.finess, b.raison_sociale, b.commune, b.code_commune_insee,
       b.code_departement, b.date_chargement
FROM chu_bronze.esatis_etablissement b
LEFT OUTER JOIN chu_silver.etablissement s ON s.finess = b.finess
WHERE s.finess IS NULL;

INSERT INTO TABLE chu_silver.etablissement
SELECT finess, raison_sociale, commune, code_commune_insee, code_departement, date_chargement
FROM chu_bronze.esatis_etab_nouveaux;

-- Contrôles
SELECT COUNT(*) AS lignes_bronze_deces FROM chu_bronze.deces_insee;

SELECT COUNT(*) AS deces_2019,
       SUM(CASE WHEN sexe = 'I' THEN 1 ELSE 0 END) AS sexe_inconnu,
       SUM(CASE WHEN age_deces IS NULL THEN 1 ELSE 0 END) AS age_inconnu,
       SUM(CASE WHEN code_departement = '99' THEN 1 ELSE 0 END) AS deces_a_l_etranger
FROM chu_silver.deces;

SELECT COUNT(*) AS etablissements_ajoutes FROM chu_bronze.esatis_etab_nouveaux;

SELECT COUNT(*) AS etablissements_silver, COUNT(DISTINCT finess) AS finess_distincts
FROM chu_silver.etablissement;

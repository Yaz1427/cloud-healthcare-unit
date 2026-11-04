-- =====================================================================
-- 01_silver_ddl.sql : tables externes de la couche Silver
--
-- Rôle    : exposer à Hive les fichiers nettoyés et pseudonymisés que
--           les jobs Talend J05 et J10 à J13 écrivent dans HDFS.
-- Entrée  : fichiers texte de /datalake/silver/ et /datalake/referentiels/
-- Sortie  : base chu_silver, lue par J20 et J21 (sql/03 et sql/04)
-- Moteur  : Hive 1.1
--
-- C’est le contrat entre Talend et la Gold : les jobs produisent
-- exactement ces colonnes, dans cet ordre. Si DATA 2024 ne fournit pas
-- une valeur, le champ reste vide et l’écart est noté dans le rapport.
--
-- Format commun : séparateur point-virgule, sans ligne d’en-tête (sauf
-- les référentiels du COG), UTF-8, dates au format yyyy-MM-dd.
-- Le séparateur est écrit '\073', code octal du point-virgule : un
-- point-virgule entre quotes ferait couper l’instruction par Beeline.
-- Un champ vide est lu comme NULL (NULL DEFINED AS), ce qui rend les
-- mesures de complétude de sql/07 exactes.
-- Tables externes : un DROP TABLE ne supprime jamais les fichiers.
-- =====================================================================

USE chu_silver;

-- ---------------------------------------------------------------------
-- Source S1 (PostgreSQL DATA 2024), écrite par J10_silver_actes
-- ---------------------------------------------------------------------

CREATE EXTERNAL TABLE IF NOT EXISTS patient (
  patient_pseudo   STRING COMMENT 'SHA-256 sale de l identifiant source (R9)',
  sexe             STRING COMMENT 'M, F ou I (R2)',
  annee_naissance  INT    COMMENT 'Annee seule (R8)',
  code_departement STRING COMMENT 'Departement de residence (R6)',
  date_chargement  DATE
)
COMMENT 'Patients pseudonymises, sans donnee directement identifiante'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/patient';

CREATE EXTERNAL TABLE IF NOT EXISTS professionnel (
  identifiant_source STRING COMMENT 'Identifiant du professionnel dans S1',
  profession         STRING,
  specialite         STRING,
  categorie          STRING,
  date_chargement    DATE
)
COMMENT 'Professionnels de sante'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/professionnel';

CREATE EXTERNAL TABLE IF NOT EXISTS diagnostic (
  code_diagnostic    STRING COMMENT 'Majuscules, sans espaces (R11)',
  libelle_diagnostic STRING,
  date_chargement    DATE
)
COMMENT 'Diagnostics'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/diagnostic';

CREATE EXTERNAL TABLE IF NOT EXISTS consultation (
  id_consultation           STRING COMMENT 'Numero de la consultation dans S1',
  patient_pseudo            STRING,
  identifiant_professionnel STRING,
  code_diagnostic           STRING,
  finess                    STRING COMMENT 'NULL si absent ou mal forme (R5)',
  date_consultation         DATE,
  age_patient               INT    COMMENT 'Age a la date de la consultation (R8)',
  date_chargement           DATE
)
COMMENT 'Consultations nettoyees et pseudonymisees'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/consultation';

CREATE EXTERNAL TABLE IF NOT EXISTS hospitalisation (
  id_hospitalisation STRING COMMENT 'Numero du sejour dans S1',
  patient_pseudo     STRING,
  finess             STRING COMMENT 'NULL si absent ou mal forme (R5)',
  code_diagnostic    STRING COMMENT 'Diagnostic principal',
  date_entree        DATE,
  date_sortie        DATE,
  duree_sejour       INT    COMMENT 'En jours',
  age_patient        INT    COMMENT 'Age a la date d entree (R8)',
  date_chargement    DATE
)
COMMENT 'Sejours nettoyes et pseudonymises'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/hospitalisation';

-- ---------------------------------------------------------------------
-- Source S2 (référentiel des établissements), écrite par J11
-- ---------------------------------------------------------------------

CREATE EXTERNAL TABLE IF NOT EXISTS etablissement (
  finess             STRING COMMENT '9 caracteres (R5)',
  raison_sociale     STRING,
  commune            STRING,
  code_commune_insee STRING,
  code_departement   STRING COMMENT 'Deduit du code commune (R6)',
  date_chargement    DATE
)
COMMENT 'Referentiel des etablissements'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/etablissement';

-- ---------------------------------------------------------------------
-- Source S3 (notes de satisfaction), écrite par J12
-- ---------------------------------------------------------------------

CREATE EXTERNAL TABLE IF NOT EXISTS satisfaction (
  finess          STRING COMMENT 'NULL si absent ou mal forme (R5)',
  annee_recueil   INT,
  score_global    DOUBLE COMMENT 'Echelle unique fixee par J12',
  nb_repondants   INT,
  date_chargement DATE
)
COMMENT 'Satisfaction : un etablissement par annee de recueil'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/satisfaction';

-- ---------------------------------------------------------------------
-- Source S4 (décès de l’INSEE), écrite par J13
-- ---------------------------------------------------------------------

CREATE EXTERNAL TABLE IF NOT EXISTS deces (
  sexe             STRING COMMENT 'M, F ou I (R2)',
  date_deces       DATE   COMMENT '1er janvier si la date est partielle (R12)',
  age_deces        INT,
  code_departement STRING COMMENT 'Departement du lieu de deces (R6)',
  date_chargement  DATE
)
COMMENT 'Deces INSEE sans aucune donnee nominative'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/silver/deces';

-- ---------------------------------------------------------------------
-- Référentiels du COG de l’INSEE, écrits par J05_ref_cog
-- (avec une ligne d’en-tête, ignorée par Hive)
-- ---------------------------------------------------------------------

CREATE EXTERNAL TABLE IF NOT EXISTS ref_departement (
  code_departement STRING,
  code_region      STRING,
  nom_departement  STRING
)
COMMENT 'Departements du COG'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/referentiels/cog_insee/departement'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS ref_region (
  code_region STRING,
  nom_region  STRING
)
COMMENT 'Regions du COG'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073' NULL DEFINED AS ''
STORED AS TEXTFILE
LOCATION '/datalake/referentiels/cog_insee/region'
TBLPROPERTIES ('skip.header.line.count'='1');

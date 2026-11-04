-- =====================================================================
-- 02_gold_ddl.sql : constellation de la couche Gold (base chu_dw)
--
-- Rôle    : créer les 6 dimensions, les 4 tables de faits et les
--           2 tables d’agrégats de l’entrepôt.
-- Sortie  : tables gérées de chu_dw, lues par Hive, Impala et Power BI
-- Moteur  : Hive 1.1 (tables lues aussi par Impala 2.9)
--
-- Choix physiques (livrable 1, partie 4.4) :
--   - Parquet compressé en Snappy : format en colonnes, lu par Hive et
--     par Impala. La compression est fixée au chargement, par
--     SET parquet.compression=SNAPPY dans sql/03, sql/04 et sql/05.
--   - Faits et agrégats partitionnés par année (annee) : une requête
--     filtrée sur l’année ne lit que le répertoire de cette année.
--   - dim_patient, fait_consultation et fait_hospitalisation : 4 buckets
--     triés sur id_patient, pour la jointure SMB entre faits et patients.
--   - Dates en STRING au format yyyy-MM-dd : Hive 1.1 n’écrit pas le type
--     DATE en Parquet et Impala 2.9 ne le connaît pas.
--   - Pas d’index Hive : Impala ne s’en sert pas et Hive les a supprimés
--     en version 3.0. Partitions, buckets triés, statistiques et agrégats
--     jouent ce rôle.
--
-- Intégrité : Hive 1.1 ne déclare ni clé primaire ni clé étrangère.
-- Les clés sont garanties par le chargement (clés de substitution et
-- membre inconnu -1, sql/03 et sql/04) et vérifiées par sql/07.
--
-- Les tables bucketées ne se rechargent que par INSERT OVERWRITE : sous
-- Hive 1.x, un INSERT INTO y ajoute des fichiers hors du découpage en
-- buckets, sans aucune erreur.
-- =====================================================================

USE chu_dw;

-- ---------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_temps (
  id_temps      INT    COMMENT 'Cle AAAAMMJJ',
  date_complete STRING COMMENT 'yyyy-MM-dd, DATE au modele logique',
  jour          INT,
  mois          INT,
  libelle_mois  STRING,
  trimestre     INT,
  annee         INT,
  jour_semaine  STRING
)
COMMENT 'Calendrier : une ligne par jour, sans membre inconnu'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS dim_patient (
  id_patient       INT    COMMENT 'Cle de substitution, -1 pour inconnu',
  patient_pseudo   STRING COMMENT 'Cle metier : SHA-256 sale',
  sexe             STRING COMMENT 'M, F ou I',
  annee_naissance  INT,
  code_departement STRING
)
COMMENT 'Patients pseudonymises'
CLUSTERED BY (id_patient) SORTED BY (id_patient) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS dim_professionnel (
  id_professionnel   INT    COMMENT 'Cle de substitution, -1 pour inconnu',
  identifiant_source STRING COMMENT 'Cle metier',
  profession         STRING,
  specialite         STRING,
  categorie          STRING
)
COMMENT 'Professionnels de sante'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS dim_diagnostic (
  id_diagnostic      INT    COMMENT 'Cle de substitution, -1 pour inconnu',
  code_diagnostic    STRING COMMENT 'Cle metier',
  libelle_diagnostic STRING
)
COMMENT 'Diagnostics'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS dim_etablissement (
  id_etablissement   INT    COMMENT 'Cle de substitution, -1 pour inconnu',
  finess             STRING COMMENT 'Cle metier',
  raison_sociale     STRING,
  commune            STRING,
  code_commune_insee STRING,
  code_departement   STRING,
  code_region        STRING COMMENT 'Lien vers dim_region dans Power BI',
  nom_region         STRING
)
COMMENT 'Etablissements, region denormalisee'
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS dim_region (
  id_region   INT    COMMENT 'Cle de substitution, -1 pour inconnu',
  code_region STRING COMMENT 'Cle metier : code INSEE de la region',
  nom_region  STRING
)
COMMENT 'Regions du COG'
STORED AS PARQUET;

-- ---------------------------------------------------------------------
-- Tables de faits
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fait_consultation (
  id_consultation  STRING COMMENT 'Dimension degeneree, cle primaire',
  id_temps         INT    COMMENT 'FK dim_temps : date de la consultation',
  id_patient       INT    COMMENT 'FK dim_patient',
  id_professionnel INT    COMMENT 'FK dim_professionnel',
  id_diagnostic    INT    COMMENT 'FK dim_diagnostic',
  id_etablissement INT    COMMENT 'FK dim_etablissement',
  age_patient      INT    COMMENT 'Mesure non additive',
  nb_consultation  INT    COMMENT 'Mesure additive, vaut 1'
)
COMMENT 'Grain : une consultation'
PARTITIONED BY (annee INT)
CLUSTERED BY (id_patient) SORTED BY (id_patient) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS fait_hospitalisation (
  id_hospitalisation STRING COMMENT 'Dimension degeneree, cle primaire',
  id_temps           INT    COMMENT 'FK dim_temps : date d entree',
  id_patient         INT    COMMENT 'FK dim_patient',
  id_diagnostic      INT    COMMENT 'FK dim_diagnostic : diagnostic principal',
  id_etablissement   INT    COMMENT 'FK dim_etablissement',
  age_patient        INT    COMMENT 'Mesure non additive',
  duree_sejour       INT    COMMENT 'Mesure additive, en jours',
  nb_hospitalisation INT    COMMENT 'Mesure additive, vaut 1'
)
COMMENT 'Grain : un sejour'
PARTITIONED BY (annee INT)
CLUSTERED BY (id_patient) SORTED BY (id_patient) INTO 4 BUCKETS
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS fait_deces (
  id_temps  INT    COMMENT 'FK dim_temps : date du deces',
  id_region INT    COMMENT 'FK dim_region : region du lieu de deces',
  sexe      STRING COMMENT 'M, F ou I',
  age_deces INT    COMMENT 'Mesure non additive',
  nb_deces  INT    COMMENT 'Mesure additive, vaut 1'
)
COMMENT 'Grain : un deces, aucune donnee nominative'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS fait_satisfaction (
  id_temps         INT    COMMENT 'FK dim_temps : 1er janvier de l annee de recueil',
  id_etablissement INT    COMMENT 'FK dim_etablissement',
  score_global     DOUBLE COMMENT 'Mesure non additive',
  nb_repondants    INT    COMMENT 'Mesure additive, poids de la moyenne'
)
COMMENT 'Grain : un etablissement par annee de recueil'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

-- ---------------------------------------------------------------------
-- Tables d’agrégats : elles remplacent les vues matérialisées,
-- absentes de Hive 1.1, et servent les KPI additifs (1, 2, 4, 5, 6)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS agg_consultation_mois (
  mois             INT,
  id_etablissement INT,
  id_diagnostic    INT,
  id_professionnel INT,
  nb_consultation  BIGINT
)
COMMENT 'Consultations par mois, etablissement, diagnostic et professionnel'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

CREATE TABLE IF NOT EXISTS agg_hospitalisation_mois (
  mois               INT,
  id_etablissement   INT,
  id_diagnostic      INT,
  sexe               STRING,
  tranche_age        STRING,
  nb_hospitalisation BIGINT,
  nb_jours           BIGINT
)
COMMENT 'Sejours par mois, etablissement, diagnostic, sexe et tranche d age'
PARTITIONED BY (annee INT)
STORED AS PARQUET;

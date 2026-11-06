-- =====================================================================
-- 03_qualite_source.sql : mesures de qualité de DATA 2024, à la source
--
-- Rôle    : compter, pour le rapport de qualité, ce que les règles de
--           nettoyage écartent ou rattachent au membre inconnu (-1) :
--           complétude, validité (dates, FINESS), doublons, références
--           absentes. Aucune donnée de patient ne sort : que des comptages.
-- Moteur  : PostgreSQL (psql ou PSQL Tool de pgAdmin), base data2024
-- Entrée  : les tables de DATA 2024 et C:/chu/sources/Hospitalisations.csv
-- Sortie  : C:/chu/silver/qualite_source.csv (et le même tableau à l'écran)
--
-- Lancement, dans le PSQL Tool ouvert sur data2024 (pas besoin du sel) :
--   \i 'C:/chu/chargement/03_qualite_source.sql'
-- =====================================================================

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION pg_temp.date_mja(t text) RETURNS date AS $$
BEGIN
  IF t IS NULL OR trim(t) !~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN RETURN NULL; END IF;
  RETURN make_date(split_part(trim(t), '/', 3)::int,
                   split_part(trim(t), '/', 1)::int,
                   split_part(trim(t), '/', 2)::int);
EXCEPTION WHEN others THEN RETURN NULL;
END $$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION pg_temp.date_jma(t text) RETURNS date AS $$
BEGIN
  IF t IS NULL OR trim(t) !~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN RETURN NULL; END IF;
  RETURN make_date(split_part(trim(t), '/', 3)::int,
                   split_part(trim(t), '/', 2)::int,
                   split_part(trim(t), '/', 1)::int);
EXCEPTION WHEN others THEN RETURN NULL;
END $$ LANGUAGE plpgsql IMMUTABLE;

-- Fichier des hospitalisations, lu comme dans 01_extraction_s1.sql
DROP TABLE IF EXISTS q_hosp_ligne;
DROP TABLE IF EXISTS q_hosp;
CREATE TEMP TABLE q_hosp_ligne (ligne text);
\copy q_hosp_ligne FROM 'C:/chu/sources/Hospitalisations.csv' WITH (FORMAT csv, DELIMITER E'\x01', QUOTE E'\x02', HEADER true, ENCODING 'LATIN1')

CREATE TEMP TABLE q_hosp AS
SELECT NULLIF(btrim(split_part(l.v, ';', 1)), '') AS num_hospitalisation,
       NULLIF(btrim(split_part(l.v, ';', 2)), '') AS id_patient,
       NULLIF(btrim(split_part(l.v, ';', 3)), '') AS identifiant_organisation,
       NULLIF(btrim(split_part(l.v, ';', 4)), '') AS code_diagnostic,
       NULLIF(btrim(split_part(l.v, ';', 6)), '') AS date_entree,
       NULLIF(btrim(split_part(l.v, ';', 7)), '') AS jour_hospitalisation
FROM (SELECT replace(replace(ligne, E'\r', ''), '"', '') AS v
      FROM q_hosp_ligne WHERE ligne IS NOT NULL) l;

-- Une ligne par contrôle : nombre de lignes concernées sur le total
DROP TABLE IF EXISTS q_qualite;
CREATE TEMP TABLE q_qualite AS
WITH
pa AS (SELECT DISTINCT "Id_patient" AS id FROM "Patient"),
pr AS (SELECT DISTINCT trim("Identifiant") AS id FROM "Professionnel_de_sante"),
dg AS (SELECT DISTINCT upper(replace(trim("Code_diag"), ' ', '')) AS code FROM "Diagnostic"),
mesures AS (
  -- Complétude des consultations
  SELECT 1 AS ordre, 'completude' AS domaine, 'Consultation' AS source, 'Id_patient vide' AS controle,
         count(*) FILTER (WHERE "Id_patient" IS NULL) AS nb, count(*) AS total FROM "Consultation" co
  UNION ALL SELECT 2, 'completude', 'Consultation', 'Id_prof_sante vide',
         count(*) FILTER (WHERE NULLIF(trim("Id_prof_sante"), '') IS NULL), count(*) FROM "Consultation" co
  UNION ALL SELECT 3, 'completude', 'Consultation', 'Code_diag vide',
         count(*) FILTER (WHERE NULLIF(trim("Code_diag"), '') IS NULL), count(*) FROM "Consultation" co
  UNION ALL SELECT 4, 'completude', 'Consultation', 'Date vide (ligne ecartee, R4)',
         count(*) FILTER (WHERE "Date" IS NULL), count(*) FROM "Consultation" co
  UNION ALL SELECT 5, 'completude', 'Consultation', 'FINESS absent du schema (etablissement -1)',
         count(*), count(*) FROM "Consultation" co
  -- Complétude et validité des patients
  UNION ALL SELECT 6, 'completude', 'Patient', 'Sexe vide ou non reconnu (I, R2)',
         count(*) FILTER (WHERE upper(left(trim("Sexe"), 1)) NOT IN ('M', 'H', 'F') OR "Sexe" IS NULL), count(*) FROM "Patient" pa
  UNION ALL SELECT 7, 'validite', 'Patient', 'Date de naissance illisible (R1)',
         count(*) FILTER (WHERE pg_temp.date_mja("Date") IS NULL), count(*) FROM "Patient" pa
  UNION ALL SELECT 8, 'validite', 'Patient', 'Code postal inexploitable (departement vide, R6)',
         count(*) FILTER (WHERE NOT (lpad(trim("Code_postal"), 5, '0') ~ '^[0-9]{5}$') OR "Code_postal" IS NULL), count(*) FROM "Patient" pa
  -- Hospitalisations
  UNION ALL SELECT 9, 'completude', 'Hospitalisations.csv', 'Id_patient vide',
         count(*) FILTER (WHERE id_patient IS NULL), count(*) FROM q_hosp
  UNION ALL SELECT 10, 'validite', 'Hospitalisations.csv', 'Date_Entree vide ou illisible (ligne ecartee, R1/R4)',
         count(*) FILTER (WHERE pg_temp.date_jma(date_entree) IS NULL), count(*) FROM q_hosp
  UNION ALL SELECT 11, 'validite', 'Hospitalisations.csv', 'Duree vide ou non numerique',
         count(*) FILTER (WHERE jour_hospitalisation IS NULL OR jour_hospitalisation !~ '^[0-9]{1,4}$'), count(*) FROM q_hosp
  UNION ALL SELECT 12, 'finess', 'Hospitalisations.csv', 'FINESS vide',
         count(*) FILTER (WHERE identifiant_organisation IS NULL), count(*) FROM q_hosp
  UNION ALL SELECT 13, 'finess', 'Hospitalisations.csv', 'FINESS mal forme (R5)',
         count(*) FILTER (WHERE identifiant_organisation IS NOT NULL
                          AND upper(identifiant_organisation) !~ '^F?(2A|2B|[0-9]{2})[0-9]{7}$'), count(*) FROM q_hosp
  UNION ALL SELECT 14, 'finess', 'Hospitalisations.csv', 'Etablissements distincts (FINESS valides)',
         count(DISTINCT regexp_replace(upper(identifiant_organisation), '^F', ''))
           FILTER (WHERE upper(identifiant_organisation) ~ '^F?(2A|2B|[0-9]{2})[0-9]{7}$'), count(*) FROM q_hosp
  -- Doublons de clé (lignes en trop, retirées par R3)
  UNION ALL SELECT 15, 'doublons', 'Consultation', 'Num_consultation en double',
         count(*) - count(DISTINCT "Num_consultation"), count(*) FROM "Consultation" co
  UNION ALL SELECT 16, 'doublons', 'Patient', 'Id_patient en double',
         count(*) - count(DISTINCT "Id_patient"), count(*) FROM "Patient" pa
  UNION ALL SELECT 17, 'doublons', 'Professionnel_de_sante', 'Identifiant en double',
         count(*) - count(DISTINCT trim("Identifiant")), count(*) FROM "Professionnel_de_sante"
  UNION ALL SELECT 18, 'doublons', 'Diagnostic', 'Code_diag en double (apres R11)',
         count(*) - count(DISTINCT upper(replace(trim("Code_diag"), ' ', ''))), count(*) FROM "Diagnostic"
  UNION ALL SELECT 19, 'doublons', 'Hospitalisations.csv', 'Num_Hospitalisation en double',
         count(*) - count(DISTINCT num_hospitalisation), count(*) FROM q_hosp
  -- Références absentes (rattachées au membre -1 en Gold). Jointures
  -- externes sur des listes distinctes : une seule passe sur chaque table.
  UNION ALL SELECT 20, 'integrite', 'Consultation', 'Patient absent de Patient',
         count(*) FILTER (WHERE co."Id_patient" IS NOT NULL AND pa.id IS NULL), count(*)
  FROM "Consultation" co LEFT JOIN pa ON pa.id = co."Id_patient"
  UNION ALL SELECT 21, 'integrite', 'Consultation', 'Professionnel absent de Professionnel_de_sante',
         count(*) FILTER (WHERE NULLIF(trim(co."Id_prof_sante"), '') IS NOT NULL AND pr.id IS NULL), count(*)
  FROM "Consultation" co LEFT JOIN pr ON pr.id = trim(co."Id_prof_sante")
  UNION ALL SELECT 22, 'integrite', 'Consultation', 'Diagnostic absent de Diagnostic',
         count(*) FILTER (WHERE NULLIF(trim(co."Code_diag"), '') IS NOT NULL AND dg.code IS NULL), count(*)
  FROM "Consultation" co LEFT JOIN dg ON dg.code = upper(replace(trim(co."Code_diag"), ' ', ''))
  UNION ALL SELECT 23, 'integrite', 'Hospitalisations.csv', 'Patient absent de Patient',
         count(*) FILTER (WHERE h.id_patient ~ '^[0-9]{1,9}$' AND pa.id IS NULL), count(*)
  FROM q_hosp h LEFT JOIN pa
    ON pa.id = CASE WHEN h.id_patient ~ '^[0-9]{1,9}$' THEN h.id_patient::int END
  UNION ALL SELECT 24, 'integrite', 'Hospitalisations.csv', 'Diagnostic absent de Diagnostic',
         count(*) FILTER (WHERE h.code_diagnostic IS NOT NULL AND dg.code IS NULL), count(*)
  FROM q_hosp h LEFT JOIN dg ON dg.code = upper(replace(h.code_diagnostic, ' ', ''))
)
SELECT ordre, domaine, source, controle, nb AS nb_lignes, total AS nb_total,
       round(100.0 * nb / NULLIF(total, 0), 2) AS pct
FROM mesures;

CREATE TEMP VIEW v_qualite AS SELECT * FROM q_qualite ORDER BY ordre;
\copy (SELECT * FROM v_qualite) TO 'C:/chu/silver/qualite_source.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')

SELECT domaine, source, controle, nb_lignes, nb_total, pct FROM v_qualite;

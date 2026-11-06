-- =====================================================================
-- 01_extraction_s1.sql : extraction de DATA 2024 vers les fichiers Silver
--
-- Rôle    : produire depuis PostgreSQL les CSV de la couche Silver, au
--           format de sql/01_silver_ddl.sql, avec les règles R1 à R11 et
--           la pseudonymisation R9 (SHA-256 salé, fonction sha256).
-- Moteur  : PostgreSQL (psql ou PSQL Tool de pgAdmin), base data2024
-- Entrée  : tables "Patient", "Consultation", "Diagnostic",
--           "Professionnel_de_sante", "Specialites" et le fichier
--           C:/chu/sources/Hospitalisations.csv (copié depuis DATA 2024)
-- Sortie  : C:/chu/silver/patient.csv, professionnel.csv, diagnostic.csv,
--           consultation.csv, hospitalisation.csv, etablissement.csv
--
-- Lancement, dans le PSQL Tool ouvert sur la base data2024 :
--   \set sel 'un_secret_que_tu_choisis'
--   \i 'C:/chu/chargement/01_extraction_s1.sql'
-- Avant : créer C:\chu\silver et copier Hospitalisations.csv dans C:\chu\sources
-- Le sel n'est écrit dans aucun fichier. Les vues, fonctions et tables
-- créées ici sont temporaires : elles disparaissent à la fin de la session.
--
-- Constats sur DATA 2024 appliqués ici :
--   - "Patient"."Date" (naissance) est un texte au format M/J/AAAA
--   - "Consultation" n'a pas de FINESS : établissement inconnu (-1) en Gold
--   - les hospitalisations sont un fichier CSV (séparateur ;), pas une table
--   - "identifiant_organisation" vaut F + FINESS, Date_Entree est en JJ/MM/AAAA
--   - établissements : FINESS des séjours, département = 2 premiers
--     caractères du FINESS (970x : 97x)
-- =====================================================================

\set ON_ERROR_STOP on
\if :{?sel}
\else
  \echo 'ERREUR : definis d abord le sel (voir l en-tete du script), puis relance.'
  \quit
\endif
SET client_encoding = 'UTF8';

-- Relance possible dans la même session : on repart de zéro
DISCARD TEMP;

-- Paramètres de la session : le sel et la date du chargement
CREATE TEMP TABLE chu_param AS
SELECT :'sel'::text AS sel, current_date AS date_chargement;

-- Conversion sûre d'une date texte : NULL au lieu d'une erreur (R1)
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

-- ---------------------------------------------------------------------
-- Patients : un par identifiant (R3), naissance convertie (R1), sexe
-- normalisé (R2), département déduit du code postal (R6)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE t_patient AS
SELECT DISTINCT ON (p."Id_patient")
       p."Id_patient" AS id_patient,
       CASE upper(left(trim(p."Sexe"), 1))
         WHEN 'M' THEN 'M' WHEN 'H' THEN 'M' WHEN 'F' THEN 'F' ELSE 'I'
       END AS sexe,
       pg_temp.date_mja(p."Date") AS date_naissance,
       CASE
         WHEN cp.v ~ '^97[0-9]{3}$' THEN left(cp.v, 3)
         WHEN cp.v ~ '^20[0-9]{3}$' THEN CASE WHEN left(cp.v, 3) IN ('200', '201') THEN '2A' ELSE '2B' END
         WHEN cp.v ~ '^[0-9]{5}$' THEN left(cp.v, 2)
       END AS code_departement
FROM "Patient" p
CROSS JOIN LATERAL (
  SELECT CASE WHEN trim(p."Code_postal") ~ '^[0-9]{4}$' THEN lpad(trim(p."Code_postal"), 5, '0')
              ELSE trim(p."Code_postal") END AS v) cp
WHERE p."Id_patient" IS NOT NULL
ORDER BY p."Id_patient";
CREATE INDEX ON t_patient (id_patient);

CREATE TEMP VIEW v_patient AS
SELECT encode(sha256(convert_to(c.sel || t.id_patient::text, 'UTF8')), 'hex') AS patient_pseudo,
       t.sexe,
       extract(year FROM t.date_naissance)::int AS annee_naissance,
       t.code_departement,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM t_patient t
CROSS JOIN chu_param c;

-- ---------------------------------------------------------------------
-- Professionnels : un par identifiant, sans nom ni prénom (R10)
-- ---------------------------------------------------------------------
CREATE TEMP VIEW v_professionnel AS
SELECT DISTINCT ON (trim(pr."Identifiant"))
       trim(pr."Identifiant") AS identifiant_source,
       COALESCE(NULLIF(trim(translate(pr."Profession", E';\n\r', ',  ')), ''), 'Non renseigné') AS profession,
       COALESCE(NULLIF(trim(translate(sp."Specialite", E';\n\r', ',  ')), ''), 'Non renseigné') AS specialite,
       COALESCE(NULLIF(trim(translate(pr."Categorie_professionnelle", E';\n\r', ',  ')), ''), 'Non renseigné') AS categorie,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM "Professionnel_de_sante" pr
CROSS JOIN chu_param c
LEFT JOIN "Specialites" sp ON sp."Code_specialite" = pr."Code_specialite"
WHERE NULLIF(trim(pr."Identifiant"), '') IS NOT NULL
ORDER BY trim(pr."Identifiant");

-- ---------------------------------------------------------------------
-- Diagnostics : codes en majuscules sans espaces (R11)
-- ---------------------------------------------------------------------
CREATE TEMP VIEW v_diagnostic AS
SELECT DISTINCT ON (upper(replace(trim(d."Code_diag"), ' ', '')))
       upper(replace(trim(d."Code_diag"), ' ', '')) AS code_diagnostic,
       COALESCE(NULLIF(trim(translate(d."Diagnostic", E';\n\r', ',  ')), ''), 'Non renseigné') AS libelle_diagnostic,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM "Diagnostic" d
CROSS JOIN chu_param c
WHERE NULLIF(trim(d."Code_diag"), '') IS NOT NULL
ORDER BY upper(replace(trim(d."Code_diag"), ' ', ''));

-- ---------------------------------------------------------------------
-- Consultations : une par numéro (R3), sans date : écartée (R4),
-- patient pseudonymisé (R9), âge à la date de la consultation (R8)
-- ---------------------------------------------------------------------
CREATE TEMP VIEW v_consultation AS
SELECT DISTINCT ON (co."Num_consultation")
       co."Num_consultation"::text AS id_consultation,
       CASE WHEN co."Id_patient" IS NOT NULL
            THEN encode(sha256(convert_to(c.sel || co."Id_patient"::text, 'UTF8')), 'hex') END AS patient_pseudo,
       NULLIF(trim(co."Id_prof_sante"), '') AS identifiant_professionnel,
       NULLIF(upper(replace(trim(co."Code_diag"), ' ', '')), '') AS code_diagnostic,
       NULL::text AS finess,
       to_char(co."Date", 'YYYY-MM-DD') AS date_consultation,
       CASE WHEN tp.date_naissance <= co."Date"
            THEN date_part('year', age(co."Date", tp.date_naissance))::int END AS age_patient,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM "Consultation" co
CROSS JOIN chu_param c
LEFT JOIN t_patient tp ON tp.id_patient = co."Id_patient"
WHERE co."Num_consultation" IS NOT NULL AND co."Date" IS NOT NULL
ORDER BY co."Num_consultation";

-- ---------------------------------------------------------------------
-- Hospitalisations : fichier CSV chargé tel quel, puis nettoyé
-- ---------------------------------------------------------------------
-- Chaque ligne est lue comme un seul champ (séparateur et guillemet
-- impossibles), puis découpée sur le point-virgule : une colonne en trop
-- ou un guillemet parasite ne fait pas échouer le chargement.
CREATE TEMP TABLE t_hosp_ligne (ligne text);
\copy t_hosp_ligne FROM 'C:/chu/sources/Hospitalisations.csv' WITH (FORMAT csv, DELIMITER E'\x01', QUOTE E'\x02', HEADER true, ENCODING 'LATIN1')

CREATE TEMP TABLE t_hosp_brut AS
SELECT NULLIF(btrim(split_part(l.v, ';', 1)), '') AS num_hospitalisation,
       NULLIF(btrim(split_part(l.v, ';', 2)), '') AS id_patient,
       NULLIF(btrim(split_part(l.v, ';', 3)), '') AS identifiant_organisation,
       NULLIF(btrim(split_part(l.v, ';', 4)), '') AS code_diagnostic,
       NULLIF(btrim(split_part(l.v, ';', 6)), '') AS date_entree,
       NULLIF(btrim(split_part(l.v, ';', 7)), '') AS jour_hospitalisation
FROM (SELECT replace(replace(ligne, E'\r', ''), '"', '') AS v
      FROM t_hosp_ligne WHERE ligne IS NOT NULL) l;

CREATE TEMP VIEW v_hospitalisation AS
SELECT DISTINCT ON (h.num_hospitalisation)
       h.num_hospitalisation AS id_hospitalisation,
       CASE WHEN e.id_patient IS NOT NULL
            THEN encode(sha256(convert_to(c.sel || e.id_patient, 'UTF8')), 'hex') END AS patient_pseudo,
       CASE WHEN upper(h.identifiant_organisation) ~ '^F?(2A|2B|[0-9]{2})[0-9]{7}$'
            THEN regexp_replace(upper(h.identifiant_organisation), '^F', '') END AS finess,
       NULLIF(upper(replace(h.code_diagnostic, ' ', '')), '') AS code_diagnostic,
       to_char(e.date_entree, 'YYYY-MM-DD') AS date_entree,
       to_char(e.date_entree + e.duree, 'YYYY-MM-DD') AS date_sortie,
       e.duree AS duree_sejour,
       CASE WHEN tp.date_naissance <= e.date_entree
            THEN date_part('year', age(e.date_entree, tp.date_naissance))::int END AS age_patient,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM t_hosp_brut h
CROSS JOIN chu_param c
CROSS JOIN LATERAL (
  SELECT pg_temp.date_jma(h.date_entree) AS date_entree,
         CASE WHEN h.jour_hospitalisation ~ '^[0-9]{1,4}$'
              THEN h.jour_hospitalisation::int END AS duree,
         CASE WHEN h.id_patient ~ '^[0-9]{1,9}$'
              THEN (h.id_patient::int)::text ELSE h.id_patient END AS id_patient) e
LEFT JOIN t_patient tp ON tp.id_patient::text = e.id_patient
WHERE h.num_hospitalisation IS NOT NULL AND e.date_entree IS NOT NULL
ORDER BY h.num_hospitalisation;

-- ---------------------------------------------------------------------
-- Établissements : FINESS présents dans les séjours. Le département vient
-- du FINESS (2 premiers caractères, 97x pour l'outre-mer), la région
-- sera ajoutée en Gold grâce au COG (R6).
-- ---------------------------------------------------------------------
CREATE TEMP VIEW v_etablissement AS
SELECT f.finess,
       'Non renseigné' AS raison_sociale,
       NULL::text AS commune,
       NULL::text AS code_commune_insee,
       CASE WHEN f.finess LIKE '97%' THEN '97' || substr(f.finess, 4, 1)
            ELSE left(f.finess, 2) END AS code_departement,
       to_char(c.date_chargement, 'YYYY-MM-DD') AS date_chargement
FROM (SELECT DISTINCT finess FROM v_hospitalisation WHERE finess IS NOT NULL) f
CROSS JOIN chu_param c;

-- ---------------------------------------------------------------------
-- Export des fichiers Silver : séparateur ; et champ vide pour NULL
-- ---------------------------------------------------------------------
\copy (SELECT * FROM v_patient) TO 'C:/chu/silver/patient.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy (SELECT * FROM v_professionnel) TO 'C:/chu/silver/professionnel.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy (SELECT * FROM v_diagnostic) TO 'C:/chu/silver/diagnostic.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy (SELECT * FROM v_consultation) TO 'C:/chu/silver/consultation.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy (SELECT * FROM v_hospitalisation) TO 'C:/chu/silver/hospitalisation.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy (SELECT * FROM v_etablissement) TO 'C:/chu/silver/etablissement.csv' WITH (FORMAT text, DELIMITER ';', NULL '', ENCODING 'UTF8')

-- Comptages pour le rapport
SELECT 'patient' AS fichier, count(*) AS lignes FROM v_patient
UNION ALL SELECT 'professionnel', count(*) FROM v_professionnel
UNION ALL SELECT 'diagnostic', count(*) FROM v_diagnostic
UNION ALL SELECT 'consultation', count(*) FROM v_consultation
UNION ALL SELECT 'hospitalisation', count(*) FROM v_hospitalisation
UNION ALL SELECT 'etablissement', count(*) FROM v_etablissement
UNION ALL SELECT 'hospitalisations brutes', count(*) FROM t_hosp_ligne
UNION ALL SELECT 'consultations brutes', count(*) FROM "Consultation";

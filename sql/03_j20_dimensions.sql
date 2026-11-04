-- =====================================================================
-- 03_j20_dimensions.sql : chargement des dimensions (job J20)
--
-- Rôle    : alimenter les 6 dimensions de chu_dw.
-- Entrée  : chu_silver (tables de sql/01)
-- Sortie  : dim_region, dim_etablissement, dim_patient,
--           dim_professionnel, dim_diagnostic, dim_temps
-- Moteur  : Hive 1.1. Dans Talend : une instruction par tHiveRow, les SET
--           dans les propriétés Hive avancées du tHiveConnection.
--
-- Une même requête sert au premier chargement et aux suivants, en trois
-- blocs réunis par UNION ALL :
--   1) membres déjà connus : clé conservée, attributs rafraîchis (SCD 1)
--   2) nouveaux membres : plus grande clé existante + rang
--   3) membre inconnu -1, ajouté seulement s’il manque
-- Renuméroter une dimension ferait pointer les faits des années non
-- rechargées vers de mauvaises lignes, sans aucune erreur visible.
-- Le membre -1 passe par l’INSERT OVERWRITE lui-même, car dim_patient est
-- bucketée et ne doit jamais recevoir d’INSERT INTO.
--
-- Ordre : dim_region en premier, car dim_temps s’appuie sur son membre -1.
-- Fichier en UTF-8 : lancer Beeline avec une locale UTF-8
-- (export LANG=en_US.UTF-8), sinon les accents des libellés sont perdus.
-- =====================================================================

USE chu_dw;
SET hive.enforce.bucketing=true;
SET hive.enforce.sorting=true;
SET hive.auto.convert.join=true;
SET parquet.compression=SNAPPY;

-- ---------------------------------------------------------------------
-- dim_region : régions du COG, clé métier code_region
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_region
SELECT u.id_region, u.code_region, u.nom_region
FROM (
  -- 1) Membres connus
  SELECT d.id_region, d.code_region,
         COALESCE(s.nom_region, d.nom_region) AS nom_region
  FROM dim_region d
  LEFT OUTER JOIN chu_silver.ref_region s ON s.code_region = d.code_region
  UNION ALL
  -- 2) Nouvelles régions
  SELECT CAST(m.max_id + n.rang AS INT) AS id_region, n.code_region, n.nom_region
  FROM (SELECT s.code_region, s.nom_region,
               ROW_NUMBER() OVER (ORDER BY s.code_region) AS rang
        FROM chu_silver.ref_region s
        LEFT OUTER JOIN dim_region d ON d.code_region = s.code_region
        WHERE d.id_region IS NULL) n
  CROSS JOIN (SELECT CASE WHEN MAX(id_region) > 0 THEN MAX(id_region) ELSE 0 END
                       AS max_id
              FROM dim_region) m
  UNION ALL
  -- 3) Membre inconnu
  SELECT CAST(-1 AS INT) AS id_region, 'NC' AS code_region, 'Inconnue' AS nom_region
  FROM (SELECT COUNT(*) AS nb FROM dim_region WHERE id_region = -1) k
  WHERE k.nb = 0
) u;

-- ---------------------------------------------------------------------
-- dim_etablissement : clé métier finess, région ajoutée grâce au COG (R6)
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_etablissement
SELECT u.id_etablissement, u.finess, u.raison_sociale, u.commune,
       u.code_commune_insee, u.code_departement, u.code_region, u.nom_region
FROM (
  -- 1) Membres connus : un attribut absent de la nouvelle extraction
  --    garde sa valeur précédente
  SELECT d.id_etablissement, d.finess,
         COALESCE(s.raison_sociale, d.raison_sociale)         AS raison_sociale,
         COALESCE(s.commune, d.commune)                       AS commune,
         COALESCE(s.code_commune_insee, d.code_commune_insee) AS code_commune_insee,
         COALESCE(s.code_departement, d.code_departement)     AS code_departement,
         COALESCE(s.code_region, d.code_region)               AS code_region,
         COALESCE(s.nom_region, d.nom_region)                 AS nom_region
  FROM dim_etablissement d
  LEFT OUTER JOIN (SELECT e.finess, e.raison_sociale, e.commune,
                          e.code_commune_insee, e.code_departement,
                          COALESCE(rd.code_region, 'NC')    AS code_region,
                          COALESCE(r.nom_region, 'Inconnue') AS nom_region
                   FROM chu_silver.etablissement e
                   LEFT OUTER JOIN chu_silver.ref_departement rd
                     ON rd.code_departement = e.code_departement
                   LEFT OUTER JOIN chu_silver.ref_region r
                     ON r.code_region = rd.code_region) s
    ON s.finess = d.finess
  UNION ALL
  -- 2) Nouveaux établissements
  SELECT CAST(m.max_id + n.rang AS INT) AS id_etablissement, n.finess,
         n.raison_sociale, n.commune, n.code_commune_insee, n.code_departement,
         n.code_region, n.nom_region
  FROM (SELECT s.finess, s.raison_sociale, s.commune, s.code_commune_insee,
               s.code_departement, s.code_region, s.nom_region,
               ROW_NUMBER() OVER (ORDER BY s.finess) AS rang
        FROM (SELECT e.finess, e.raison_sociale, e.commune,
                     e.code_commune_insee, e.code_departement,
                     COALESCE(rd.code_region, 'NC')    AS code_region,
                     COALESCE(r.nom_region, 'Inconnue') AS nom_region
              FROM chu_silver.etablissement e
              LEFT OUTER JOIN chu_silver.ref_departement rd
                ON rd.code_departement = e.code_departement
              LEFT OUTER JOIN chu_silver.ref_region r
                ON r.code_region = rd.code_region) s
        LEFT OUTER JOIN dim_etablissement d ON d.finess = s.finess
        WHERE d.id_etablissement IS NULL) n
  CROSS JOIN (SELECT CASE WHEN MAX(id_etablissement) > 0 THEN MAX(id_etablissement)
                          ELSE 0 END AS max_id
              FROM dim_etablissement) m
  UNION ALL
  -- 3) Membre inconnu
  SELECT CAST(-1 AS INT) AS id_etablissement, 'INCONNU' AS finess,
         'Etablissement inconnu' AS raison_sociale, 'INCONNU' AS commune,
         'INCONNU' AS code_commune_insee, 'NC' AS code_departement,
         'NC' AS code_region, 'Inconnue' AS nom_region
  FROM (SELECT COUNT(*) AS nb FROM dim_etablissement WHERE id_etablissement = -1) k
  WHERE k.nb = 0
) u;

-- ---------------------------------------------------------------------
-- dim_patient : clé métier patient_pseudo, table bucketée sur id_patient
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_patient
SELECT u.id_patient, u.patient_pseudo, u.sexe, u.annee_naissance, u.code_departement
FROM (
  -- 1) Membres connus
  SELECT d.id_patient, d.patient_pseudo,
         COALESCE(s.sexe, d.sexe)                         AS sexe,
         COALESCE(s.annee_naissance, d.annee_naissance)   AS annee_naissance,
         COALESCE(s.code_departement, d.code_departement) AS code_departement
  FROM dim_patient d
  LEFT OUTER JOIN chu_silver.patient s ON s.patient_pseudo = d.patient_pseudo
  UNION ALL
  -- 2) Nouveaux patients
  SELECT CAST(m.max_id + n.rang AS INT) AS id_patient, n.patient_pseudo, n.sexe,
         n.annee_naissance, n.code_departement
  FROM (SELECT s.patient_pseudo, s.sexe, s.annee_naissance, s.code_departement,
               ROW_NUMBER() OVER (ORDER BY s.patient_pseudo) AS rang
        FROM chu_silver.patient s
        LEFT OUTER JOIN dim_patient d ON d.patient_pseudo = s.patient_pseudo
        WHERE d.id_patient IS NULL) n
  CROSS JOIN (SELECT CASE WHEN MAX(id_patient) > 0 THEN MAX(id_patient) ELSE 0 END
                       AS max_id
              FROM dim_patient) m
  UNION ALL
  -- 3) Membre inconnu
  SELECT CAST(-1 AS INT) AS id_patient, 'INCONNU' AS patient_pseudo, 'I' AS sexe,
         CAST(NULL AS INT) AS annee_naissance, 'NC' AS code_departement
  FROM (SELECT COUNT(*) AS nb FROM dim_patient WHERE id_patient = -1) k
  WHERE k.nb = 0
) u;

-- ---------------------------------------------------------------------
-- dim_professionnel : clé métier identifiant_source
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_professionnel
SELECT u.id_professionnel, u.identifiant_source, u.profession, u.specialite, u.categorie
FROM (
  -- 1) Membres connus
  SELECT d.id_professionnel, d.identifiant_source,
         COALESCE(s.profession, d.profession) AS profession,
         COALESCE(s.specialite, d.specialite) AS specialite,
         COALESCE(s.categorie, d.categorie)   AS categorie
  FROM dim_professionnel d
  LEFT OUTER JOIN chu_silver.professionnel s
    ON s.identifiant_source = d.identifiant_source
  UNION ALL
  -- 2) Nouveaux professionnels
  SELECT CAST(m.max_id + n.rang AS INT) AS id_professionnel, n.identifiant_source,
         n.profession, n.specialite, n.categorie
  FROM (SELECT s.identifiant_source, s.profession, s.specialite, s.categorie,
               ROW_NUMBER() OVER (ORDER BY s.identifiant_source) AS rang
        FROM chu_silver.professionnel s
        LEFT OUTER JOIN dim_professionnel d
          ON d.identifiant_source = s.identifiant_source
        WHERE d.id_professionnel IS NULL) n
  CROSS JOIN (SELECT CASE WHEN MAX(id_professionnel) > 0 THEN MAX(id_professionnel)
                          ELSE 0 END AS max_id
              FROM dim_professionnel) m
  UNION ALL
  -- 3) Membre inconnu
  SELECT CAST(-1 AS INT) AS id_professionnel, 'INCONNU' AS identifiant_source,
         'Inconnu' AS profession, 'Inconnu' AS specialite, 'Inconnu' AS categorie
  FROM (SELECT COUNT(*) AS nb FROM dim_professionnel WHERE id_professionnel = -1) k
  WHERE k.nb = 0
) u;

-- ---------------------------------------------------------------------
-- dim_diagnostic : clé métier code_diagnostic
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_diagnostic
SELECT u.id_diagnostic, u.code_diagnostic, u.libelle_diagnostic
FROM (
  -- 1) Membres connus
  SELECT d.id_diagnostic, d.code_diagnostic,
         COALESCE(s.libelle_diagnostic, d.libelle_diagnostic) AS libelle_diagnostic
  FROM dim_diagnostic d
  LEFT OUTER JOIN chu_silver.diagnostic s ON s.code_diagnostic = d.code_diagnostic
  UNION ALL
  -- 2) Nouveaux diagnostics
  SELECT CAST(m.max_id + n.rang AS INT) AS id_diagnostic, n.code_diagnostic,
         n.libelle_diagnostic
  FROM (SELECT s.code_diagnostic, s.libelle_diagnostic,
               ROW_NUMBER() OVER (ORDER BY s.code_diagnostic) AS rang
        FROM chu_silver.diagnostic s
        LEFT OUTER JOIN dim_diagnostic d ON d.code_diagnostic = s.code_diagnostic
        WHERE d.id_diagnostic IS NULL) n
  CROSS JOIN (SELECT CASE WHEN MAX(id_diagnostic) > 0 THEN MAX(id_diagnostic)
                          ELSE 0 END AS max_id
              FROM dim_diagnostic) m
  UNION ALL
  -- 3) Membre inconnu
  SELECT CAST(-1 AS INT) AS id_diagnostic, 'INCONNU' AS code_diagnostic,
         'Diagnostic inconnu' AS libelle_diagnostic
  FROM (SELECT COUNT(*) AS nb FROM dim_diagnostic WHERE id_diagnostic = -1) k
  WHERE k.nb = 0
) u;

-- ---------------------------------------------------------------------
-- dim_temps : calendrier généré en HiveQL, un jour par ligne.
-- Plage : du 2000-01-01 au 2030-12-31, soit 11 323 jours. À resserrer
-- sur les années réelles de DATA 2024 une fois le profilage fait, ou à
-- élargir si J30 trouve des id_temps orphelins.
-- La requête part d’une seule ligne (le membre -1 de dim_region), que
-- posexplode démultiplie en 11 323 positions : date = début + position.
-- Clé AAAAMMJJ stable par construction, pas de membre -1.
-- Hive 1.1 n’a ni quarter() ni date_format() : le trimestre est calculé
-- et le jour de la semaine vient du motif u (1 = lundi, 7 = dimanche).
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE dim_temps
SELECT CAST(regexp_replace(c.d, '-', '') AS INT) AS id_temps,
       c.d                                       AS date_complete,
       day(c.d)                                  AS jour,
       month(c.d)                                AS mois,
       CASE month(c.d)
         WHEN 1 THEN 'janvier'  WHEN 2 THEN 'février'   WHEN 3 THEN 'mars'
         WHEN 4 THEN 'avril'    WHEN 5 THEN 'mai'       WHEN 6 THEN 'juin'
         WHEN 7 THEN 'juillet'  WHEN 8 THEN 'août'      WHEN 9 THEN 'septembre'
         WHEN 10 THEN 'octobre' WHEN 11 THEN 'novembre' ELSE 'décembre'
       END                                       AS libelle_mois,
       CAST((month(c.d) + 2) / 3 AS INT)         AS trimestre,
       year(c.d)                                 AS annee,
       CASE from_unixtime(unix_timestamp(c.d, 'yyyy-MM-dd'), 'u')
         WHEN '1' THEN 'lundi'    WHEN '2' THEN 'mardi'    WHEN '3' THEN 'mercredi'
         WHEN '4' THEN 'jeudi'    WHEN '5' THEN 'vendredi' WHEN '6' THEN 'samedi'
         ELSE 'dimanche'
       END                                       AS jour_semaine
FROM (SELECT date_add('2000-01-01', p.pos) AS d
      FROM (SELECT 1 AS un FROM dim_region WHERE id_region = -1 LIMIT 1) x
      LATERAL VIEW posexplode(split(space(11322), ' ')) p AS pos, val) c
WHERE c.d <= '2030-12-31';

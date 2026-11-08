-- =====================================================================
-- 03_gold_s3_s4.sql : satisfaction (S3) et décès (S4) dans la Gold
--
-- Rôle    : ajouter à dim_etablissement les établissements notés par
--           e-Satis, puis charger fait_deces et fait_satisfaction.
--           Les instructions sont celles de sql/03 (J20) et de sql/04 (J21),
--           recopiées sans modification : seules ces trois tables changent,
--           les consultations et les hospitalisations ne sont pas relues.
-- Job     : J20 (dim_etablissement) et J21 (deux faits)
-- Moteur  : Hive 1.1, par Beeline
-- Entrée  : chu_silver.etablissement, chu_silver.deces, chu_silver.satisfaction
-- Sortie  : dim_etablissement, fait_deces, fait_satisfaction
--
-- Lancement, depuis la racine du dépôt (mêmes réglages de mémoire que J20 et J21) :
--   $HIVE --hiveconf hive.mapred.local.mem=1024 ... -f restitution/03_gold_s3_s4.sql
-- Les clés de dim_etablissement sont stables : les séjours déjà chargés
-- gardent leur établissement, sans rechargement de fait_hospitalisation.
-- =====================================================================

USE chu_dw;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.enforce.bucketing=true;
SET hive.enforce.sorting=true;
SET hive.auto.convert.join=true;
SET parquet.compression=SNAPPY;

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
-- fait_deces : grain un décès, région du lieu de décès via le COG
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_deces PARTITION (annee)
SELECT CAST(regexp_replace(CAST(d.date_deces AS STRING), '-', '') AS INT)
                                 AS id_temps,
       COALESCE(r.id_region, -1) AS id_region,
       d.sexe,
       d.age_deces,
       1                         AS nb_deces,
       YEAR(d.date_deces)        AS annee
FROM chu_silver.deces d
LEFT OUTER JOIN chu_silver.ref_departement rd ON rd.code_departement = d.code_departement
LEFT OUTER JOIN dim_region r                  ON r.code_region = rd.code_region;

-- ---------------------------------------------------------------------
-- fait_satisfaction : grain un établissement par année de recueil,
-- daté du 1er janvier de cette année (AAAA0101)
-- ---------------------------------------------------------------------
INSERT OVERWRITE TABLE fait_satisfaction PARTITION (annee)
SELECT s.annee_recueil * 10000 + 101    AS id_temps,
       COALESCE(e.id_etablissement, -1) AS id_etablissement,
       s.score_global,
       s.nb_repondants,
       s.annee_recueil                  AS annee
FROM chu_silver.satisfaction s
LEFT OUTER JOIN dim_etablissement e ON e.finess = s.finess;

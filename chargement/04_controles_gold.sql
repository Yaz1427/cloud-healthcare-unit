-- =====================================================================
-- 04_controles_gold.sql : contrôles de la Gold exécutés par Impala
--
-- Role    : sections 2, 3, 4 et 8 de sql/07_j30_controles_qualite.sql,
--           celles qui ne lisent que chu_dw. Impala les passe en quelques
--           secondes, la ou Hive demande 20 a 40 minutes sur la VM.
--           Les sections 1, 5, 6 et 7 lisent chu_silver, dont les colonnes
--           DATE sont illisibles par Impala 2.9 : leurs mesures sont
--           prises a la source par chargement/03_qualite_source.sql.
-- Moteur  : Impala 2.9, apres sql/06_j22_impala_refresh.sql
-- Sortie  : resultats/qualite/j30_gold_impala.csv
--
-- Lancement, depuis la racine du depot :
--   impala-shell -i quickstart.cloudera -B --output_delimiter=';' --print_header -f chargement/04_controles_gold.sql -o resultats/qualite/j30_gold_impala.csv
-- =====================================================================

USE chu_dw;

-- =====================================================================
-- 2. Intégrité référentielle : clés étrangères sans ligne dans leur
--    dimension. Hive 1.1 ne déclare pas de FOREIGN KEY, ce contrôle
--    en tient lieu.
-- =====================================================================

SELECT 'fait_consultation' AS fait, COUNT(*) AS nb_lignes,
       SUM(CASE WHEN t.id_temps IS NULL THEN 1 ELSE 0 END)          AS orphelins_temps,
       SUM(CASE WHEN p.id_patient IS NULL THEN 1 ELSE 0 END)        AS orphelins_patient,
       SUM(CASE WHEN pr.id_professionnel IS NULL THEN 1 ELSE 0 END) AS orphelins_professionnel,
       SUM(CASE WHEN dg.id_diagnostic IS NULL THEN 1 ELSE 0 END)    AS orphelins_diagnostic,
       SUM(CASE WHEN e.id_etablissement IS NULL THEN 1 ELSE 0 END)  AS orphelins_etablissement
FROM fait_consultation f
LEFT OUTER JOIN dim_temps t          ON t.id_temps = f.id_temps
LEFT OUTER JOIN dim_patient p        ON p.id_patient = f.id_patient
LEFT OUTER JOIN dim_professionnel pr ON pr.id_professionnel = f.id_professionnel
LEFT OUTER JOIN dim_diagnostic dg    ON dg.id_diagnostic = f.id_diagnostic
LEFT OUTER JOIN dim_etablissement e  ON e.id_etablissement = f.id_etablissement;

SELECT 'fait_hospitalisation' AS fait, COUNT(*) AS nb_lignes,
       SUM(CASE WHEN t.id_temps IS NULL THEN 1 ELSE 0 END)         AS orphelins_temps,
       SUM(CASE WHEN p.id_patient IS NULL THEN 1 ELSE 0 END)       AS orphelins_patient,
       SUM(CASE WHEN dg.id_diagnostic IS NULL THEN 1 ELSE 0 END)   AS orphelins_diagnostic,
       SUM(CASE WHEN e.id_etablissement IS NULL THEN 1 ELSE 0 END) AS orphelins_etablissement
FROM fait_hospitalisation f
LEFT OUTER JOIN dim_temps t         ON t.id_temps = f.id_temps
LEFT OUTER JOIN dim_patient p       ON p.id_patient = f.id_patient
LEFT OUTER JOIN dim_diagnostic dg   ON dg.id_diagnostic = f.id_diagnostic
LEFT OUTER JOIN dim_etablissement e ON e.id_etablissement = f.id_etablissement;

SELECT 'fait_deces' AS fait, COUNT(*) AS nb_lignes,
       SUM(CASE WHEN t.id_temps IS NULL THEN 1 ELSE 0 END)  AS orphelins_temps,
       SUM(CASE WHEN r.id_region IS NULL THEN 1 ELSE 0 END) AS orphelins_region
FROM fait_deces f
LEFT OUTER JOIN dim_temps t  ON t.id_temps = f.id_temps
LEFT OUTER JOIN dim_region r ON r.id_region = f.id_region;

SELECT 'fait_satisfaction' AS fait, COUNT(*) AS nb_lignes,
       SUM(CASE WHEN t.id_temps IS NULL THEN 1 ELSE 0 END)         AS orphelins_temps,
       SUM(CASE WHEN e.id_etablissement IS NULL THEN 1 ELSE 0 END) AS orphelins_etablissement
FROM fait_satisfaction f
LEFT OUTER JOIN dim_temps t         ON t.id_temps = f.id_temps
LEFT OUTER JOIN dim_etablissement e ON e.id_etablissement = f.id_etablissement;

-- =====================================================================
-- 3. Unicité des clés : nombre de valeurs présentes plusieurs fois.
--    Hive 1.1 ne déclare pas de PRIMARY KEY, ce contrôle en tient lieu.
--    Pour fait_satisfaction, le membre -1 peut se répéter (livrable 1, 4.3).
-- =====================================================================

SELECT x.table_gold, x.cle, x.nb_valeurs_en_double
FROM (
  SELECT 'dim_temps' AS table_gold, 'id_temps' AS cle, COUNT(*) AS nb_valeurs_en_double
  FROM (SELECT id_temps FROM dim_temps GROUP BY id_temps HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_patient', 'id_patient', COUNT(*)
  FROM (SELECT id_patient FROM dim_patient GROUP BY id_patient HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_patient', 'patient_pseudo', COUNT(*)
  FROM (SELECT patient_pseudo FROM dim_patient GROUP BY patient_pseudo HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_professionnel', 'id_professionnel', COUNT(*)
  FROM (SELECT id_professionnel FROM dim_professionnel
        GROUP BY id_professionnel HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_professionnel', 'identifiant_source', COUNT(*)
  FROM (SELECT identifiant_source FROM dim_professionnel
        GROUP BY identifiant_source HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_diagnostic', 'id_diagnostic', COUNT(*)
  FROM (SELECT id_diagnostic FROM dim_diagnostic GROUP BY id_diagnostic HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_diagnostic', 'code_diagnostic', COUNT(*)
  FROM (SELECT code_diagnostic FROM dim_diagnostic
        GROUP BY code_diagnostic HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_etablissement', 'id_etablissement', COUNT(*)
  FROM (SELECT id_etablissement FROM dim_etablissement
        GROUP BY id_etablissement HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_etablissement', 'finess', COUNT(*)
  FROM (SELECT finess FROM dim_etablissement GROUP BY finess HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_region', 'id_region', COUNT(*)
  FROM (SELECT id_region FROM dim_region GROUP BY id_region HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'dim_region', 'code_region', COUNT(*)
  FROM (SELECT code_region FROM dim_region GROUP BY code_region HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'fait_consultation', 'id_consultation', COUNT(*)
  FROM (SELECT id_consultation FROM fait_consultation
        GROUP BY id_consultation HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'fait_hospitalisation', 'id_hospitalisation', COUNT(*)
  FROM (SELECT id_hospitalisation FROM fait_hospitalisation
        GROUP BY id_hospitalisation HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'fait_satisfaction', 'id_temps, id_etablissement (hors -1)', COUNT(*)
  FROM (SELECT id_temps, id_etablissement FROM fait_satisfaction
        WHERE id_etablissement <> -1
        GROUP BY id_temps, id_etablissement HAVING COUNT(*) > 1) d
) x
ORDER BY table_gold, cle;

-- =====================================================================
-- 4. Membres inconnus : part des faits rattachés à -1, par clé étrangère.
--    C’est la mesure directe de la qualité des rattachements.
-- =====================================================================

SELECT 'fait_consultation' AS fait, COUNT(*) AS nb_lignes,
       ROUND(100 * SUM(CASE WHEN id_patient = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_patient_inconnu,
       ROUND(100 * SUM(CASE WHEN id_professionnel = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_professionnel_inconnu,
       ROUND(100 * SUM(CASE WHEN id_diagnostic = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_diagnostic_inconnu,
       ROUND(100 * SUM(CASE WHEN id_etablissement = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_etablissement_inconnu
FROM fait_consultation;

SELECT 'fait_hospitalisation' AS fait, COUNT(*) AS nb_lignes,
       ROUND(100 * SUM(CASE WHEN id_patient = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_patient_inconnu,
       ROUND(100 * SUM(CASE WHEN id_diagnostic = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_diagnostic_inconnu,
       ROUND(100 * SUM(CASE WHEN id_etablissement = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_etablissement_inconnu
FROM fait_hospitalisation;

SELECT 'fait_deces' AS fait, COUNT(*) AS nb_lignes,
       ROUND(100 * SUM(CASE WHEN id_region = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_region_inconnue
FROM fait_deces;

SELECT 'fait_satisfaction' AS fait, COUNT(*) AS nb_lignes,
       ROUND(100 * SUM(CASE WHEN id_etablissement = -1 THEN 1 ELSE 0 END) / COUNT(*), 2)
         AS pct_etablissement_inconnu
FROM fait_satisfaction;


-- =====================================================================
-- 8. Partitions présentes : une par année chargée
-- =====================================================================

SHOW PARTITIONS fait_consultation;
SHOW PARTITIONS fait_hospitalisation;
SHOW PARTITIONS fait_deces;
SHOW PARTITIONS fait_satisfaction;

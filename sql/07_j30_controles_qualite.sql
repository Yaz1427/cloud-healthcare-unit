-- =====================================================================
-- 07_j30_controles_qualite.sql : contrôles du chargement et mesures
--                                du rapport de qualité (job J30)
--
-- Rôle    : vérifier l’intégrité de chu_dw après chaque chargement et
--           produire les chiffres du rapport de qualité du livrable 2.
-- Entrée  : chu_silver et chu_dw (sql/03 à sql/05 exécutés)
-- Sortie  : tableaux de comptages et de pourcentages, à enregistrer dans
--           resultats/qualite/ (voir resultats/README.md)
-- Moteur  : Hive 1.1 (Impala ne lit pas les colonnes DATE de chu_silver)
--
-- Sections :
--   1. Volumes de Silver et de Gold par année      attendu : écart nul
--   2. Intégrité référentielle, faits orphelins     attendu : 0
--   3. Unicité des clés de la Gold                  attendu : 0
--   4. Part des faits rattachés au membre -1
--   5. Complétude par attribut (Silver)
--   6. Cohérence des codes FINESS
--   7. Doublons restants dans la Silver             attendu : 0
--   8. Partitions présentes
-- Lancer avec --force=true pour que Beeline continue après une erreur.
-- =====================================================================

USE chu_dw;
SET hive.auto.convert.join=true;

-- =====================================================================
-- 1. Volumes : lignes de Silver et lignes de Gold, par année
-- =====================================================================

SELECT 'consultation' AS flux, COALESCE(s.annee, g.annee) AS annee,
       COALESCE(s.nb, 0) AS nb_silver, COALESCE(g.nb, 0) AS nb_gold,
       COALESCE(s.nb, 0) - COALESCE(g.nb, 0) AS ecart
FROM (SELECT YEAR(date_consultation) AS annee, COUNT(*) AS nb
      FROM chu_silver.consultation GROUP BY YEAR(date_consultation)) s
FULL OUTER JOIN (SELECT annee, COUNT(*) AS nb
                 FROM fait_consultation GROUP BY annee) g
  ON g.annee = s.annee
ORDER BY annee;

SELECT 'hospitalisation' AS flux, COALESCE(s.annee, g.annee) AS annee,
       COALESCE(s.nb, 0) AS nb_silver, COALESCE(g.nb, 0) AS nb_gold,
       COALESCE(s.nb, 0) - COALESCE(g.nb, 0) AS ecart
FROM (SELECT YEAR(date_entree) AS annee, COUNT(*) AS nb
      FROM chu_silver.hospitalisation GROUP BY YEAR(date_entree)) s
FULL OUTER JOIN (SELECT annee, COUNT(*) AS nb
                 FROM fait_hospitalisation GROUP BY annee) g
  ON g.annee = s.annee
ORDER BY annee;

SELECT 'deces' AS flux, COALESCE(s.annee, g.annee) AS annee,
       COALESCE(s.nb, 0) AS nb_silver, COALESCE(g.nb, 0) AS nb_gold,
       COALESCE(s.nb, 0) - COALESCE(g.nb, 0) AS ecart
FROM (SELECT YEAR(date_deces) AS annee, COUNT(*) AS nb
      FROM chu_silver.deces GROUP BY YEAR(date_deces)) s
FULL OUTER JOIN (SELECT annee, COUNT(*) AS nb
                 FROM fait_deces GROUP BY annee) g
  ON g.annee = s.annee
ORDER BY annee;

SELECT 'satisfaction' AS flux, COALESCE(s.annee, g.annee) AS annee,
       COALESCE(s.nb, 0) AS nb_silver, COALESCE(g.nb, 0) AS nb_gold,
       COALESCE(s.nb, 0) - COALESCE(g.nb, 0) AS ecart
FROM (SELECT annee_recueil AS annee, COUNT(*) AS nb
      FROM chu_silver.satisfaction GROUP BY annee_recueil) s
FULL OUTER JOIN (SELECT annee, COUNT(*) AS nb
                 FROM fait_satisfaction GROUP BY annee) g
  ON g.annee = s.annee
ORDER BY annee;

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
-- 5. Complétude par attribut, mesurée en Silver, là où sont les vrais
--    trous (en Gold, le membre -1 masque les absences).
--    Une valeur de remplacement compte comme absente : le sexe I et les
--    libellés « Non renseigné » posés par la règle R4.
-- =====================================================================

SELECT 'patient' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                                  AS nb_lignes,
             COUNT(patient_pseudo)                     AS n_patient_pseudo,
             COUNT(CASE WHEN sexe IN ('M', 'F') THEN 1 END) AS n_sexe,
             COUNT(annee_naissance)                    AS n_annee_naissance,
             COUNT(code_departement)                   AS n_code_departement
      FROM chu_silver.patient) t
LATERAL VIEW explode(map(
  'patient_pseudo',   t.n_patient_pseudo,
  'sexe',             t.n_sexe,
  'annee_naissance',  t.n_annee_naissance,
  'code_departement', t.n_code_departement)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'professionnel' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                   AS nb_lignes,
             COUNT(identifiant_source)  AS n_identifiant_source,
             COUNT(CASE WHEN profession NOT LIKE 'Non rens%' THEN 1 END) AS n_profession,
             COUNT(CASE WHEN specialite NOT LIKE 'Non rens%' THEN 1 END) AS n_specialite,
             COUNT(CASE WHEN categorie NOT LIKE 'Non rens%' THEN 1 END)  AS n_categorie
      FROM chu_silver.professionnel) t
LATERAL VIEW explode(map(
  'identifiant_source', t.n_identifiant_source,
  'profession',         t.n_profession,
  'specialite',         t.n_specialite,
  'categorie',          t.n_categorie)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'diagnostic' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)               AS nb_lignes,
             COUNT(code_diagnostic) AS n_code_diagnostic,
             COUNT(CASE WHEN libelle_diagnostic NOT LIKE 'Non rens%' THEN 1 END)
               AS n_libelle_diagnostic
      FROM chu_silver.diagnostic) t
LATERAL VIEW explode(map(
  'code_diagnostic',    t.n_code_diagnostic,
  'libelle_diagnostic', t.n_libelle_diagnostic)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'consultation' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                         AS nb_lignes,
             COUNT(id_consultation)           AS n_id_consultation,
             COUNT(patient_pseudo)            AS n_patient_pseudo,
             COUNT(identifiant_professionnel) AS n_identifiant_professionnel,
             COUNT(code_diagnostic)           AS n_code_diagnostic,
             COUNT(finess)                    AS n_finess,
             COUNT(date_consultation)         AS n_date_consultation,
             COUNT(age_patient)               AS n_age_patient
      FROM chu_silver.consultation) t
LATERAL VIEW explode(map(
  'id_consultation',           t.n_id_consultation,
  'patient_pseudo',            t.n_patient_pseudo,
  'identifiant_professionnel', t.n_identifiant_professionnel,
  'code_diagnostic',           t.n_code_diagnostic,
  'finess',                    t.n_finess,
  'date_consultation',         t.n_date_consultation,
  'age_patient',               t.n_age_patient)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'hospitalisation' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                  AS nb_lignes,
             COUNT(id_hospitalisation) AS n_id_hospitalisation,
             COUNT(patient_pseudo)     AS n_patient_pseudo,
             COUNT(finess)             AS n_finess,
             COUNT(code_diagnostic)    AS n_code_diagnostic,
             COUNT(date_entree)        AS n_date_entree,
             COUNT(date_sortie)        AS n_date_sortie,
             COUNT(duree_sejour)       AS n_duree_sejour,
             COUNT(age_patient)        AS n_age_patient
      FROM chu_silver.hospitalisation) t
LATERAL VIEW explode(map(
  'id_hospitalisation', t.n_id_hospitalisation,
  'patient_pseudo',     t.n_patient_pseudo,
  'finess',             t.n_finess,
  'code_diagnostic',    t.n_code_diagnostic,
  'date_entree',        t.n_date_entree,
  'date_sortie',        t.n_date_sortie,
  'duree_sejour',       t.n_duree_sejour,
  'age_patient',        t.n_age_patient)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'etablissement' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                  AS nb_lignes,
             COUNT(finess)             AS n_finess,
             COUNT(CASE WHEN raison_sociale NOT LIKE 'Non rens%' THEN 1 END)
               AS n_raison_sociale,
             COUNT(CASE WHEN commune NOT LIKE 'Non rens%' THEN 1 END) AS n_commune,
             COUNT(code_commune_insee) AS n_code_commune_insee,
             COUNT(code_departement)   AS n_code_departement
      FROM chu_silver.etablissement) t
LATERAL VIEW explode(map(
  'finess',             t.n_finess,
  'raison_sociale',     t.n_raison_sociale,
  'commune',            t.n_commune,
  'code_commune_insee', t.n_code_commune_insee,
  'code_departement',   t.n_code_departement)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'satisfaction' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)             AS nb_lignes,
             COUNT(finess)        AS n_finess,
             COUNT(annee_recueil) AS n_annee_recueil,
             COUNT(score_global)  AS n_score_global,
             COUNT(nb_repondants) AS n_nb_repondants
      FROM chu_silver.satisfaction) t
LATERAL VIEW explode(map(
  'finess',        t.n_finess,
  'annee_recueil', t.n_annee_recueil,
  'score_global',  t.n_score_global,
  'nb_repondants', t.n_nb_repondants)) c AS attribut, nb_renseignes
ORDER BY attribut;

SELECT 'deces' AS table_silver, c.attribut,
       ROUND(100 * c.nb_renseignes / t.nb_lignes, 2) AS taux_completude_pct
FROM (SELECT COUNT(*)                                       AS nb_lignes,
             COUNT(CASE WHEN sexe IN ('M', 'F') THEN 1 END) AS n_sexe,
             COUNT(date_deces)                              AS n_date_deces,
             COUNT(age_deces)                               AS n_age_deces,
             COUNT(code_departement)                        AS n_code_departement
      FROM chu_silver.deces) t
LATERAL VIEW explode(map(
  'sexe',             t.n_sexe,
  'date_deces',       t.n_date_deces,
  'age_deces',        t.n_age_deces,
  'code_departement', t.n_code_departement)) c AS attribut, nb_renseignes
ORDER BY attribut;

-- =====================================================================
-- 6. Cohérence des codes FINESS
-- =====================================================================

-- 6a. Référentiel : FINESS vides ou hors du format de la règle R5
--     (deux chiffres, ou 2A, 2B, puis sept chiffres). Attendu : 0.
SELECT COUNT(*) AS nb_lignes,
       SUM(CASE WHEN finess IS NULL THEN 1 ELSE 0 END) AS nb_finess_vides,
       SUM(CASE WHEN finess IS NOT NULL
                 AND NOT (finess RLIKE '^(2A|2B|[0-9]{2})[0-9]{7}$') THEN 1 ELSE 0 END)
         AS nb_finess_mal_formes
FROM chu_silver.etablissement;

-- 6b. Actes et notes : FINESS vides (absents ou mal formés, R5) et
--     FINESS bien formés mais absents du référentiel
SELECT x.source, x.nb_lignes, x.nb_finess_vides, x.nb_finess_hors_referentiel,
       ROUND(100 * x.nb_finess_hors_referentiel / x.nb_lignes, 2) AS pct_hors_referentiel
FROM (
  SELECT 'consultation' AS source, COUNT(*) AS nb_lignes,
         SUM(CASE WHEN c.finess IS NULL THEN 1 ELSE 0 END) AS nb_finess_vides,
         SUM(CASE WHEN c.finess IS NOT NULL AND e.finess IS NULL THEN 1 ELSE 0 END)
           AS nb_finess_hors_referentiel
  FROM chu_silver.consultation c
  LEFT OUTER JOIN chu_silver.etablissement e ON e.finess = c.finess
  UNION ALL
  SELECT 'hospitalisation', COUNT(*),
         SUM(CASE WHEN h.finess IS NULL THEN 1 ELSE 0 END),
         SUM(CASE WHEN h.finess IS NOT NULL AND e.finess IS NULL THEN 1 ELSE 0 END)
  FROM chu_silver.hospitalisation h
  LEFT OUTER JOIN chu_silver.etablissement e ON e.finess = h.finess
  UNION ALL
  SELECT 'satisfaction', COUNT(*),
         SUM(CASE WHEN s.finess IS NULL THEN 1 ELSE 0 END),
         SUM(CASE WHEN s.finess IS NOT NULL AND e.finess IS NULL THEN 1 ELSE 0 END)
  FROM chu_silver.satisfaction s
  LEFT OUTER JOIN chu_silver.etablissement e ON e.finess = s.finess
) x
ORDER BY source;

-- 6c. Les 20 FINESS hors référentiel les plus fréquents dans les actes,
--     à signaler au propriétaire du référentiel
SELECT a.finess, COUNT(*) AS nb_actes
FROM (SELECT finess FROM chu_silver.consultation
      UNION ALL
      SELECT finess FROM chu_silver.hospitalisation) a
LEFT OUTER JOIN chu_silver.etablissement e ON e.finess = a.finess
WHERE a.finess IS NOT NULL AND e.finess IS NULL
GROUP BY a.finess
ORDER BY nb_actes DESC
LIMIT 20;

-- =====================================================================
-- 7. Doublons restants dans la Silver, sur la clé métier. Attendu : 0,
--    puisque Talend les écarte (R3). Les doublons écartés se comptent
--    dans les fichiers de rejets (voir talend/README.md).
-- =====================================================================

SELECT x.table_silver, x.cle, x.nb_valeurs_en_double
FROM (
  SELECT 'consultation' AS table_silver, 'id_consultation' AS cle,
         COUNT(*) AS nb_valeurs_en_double
  FROM (SELECT id_consultation FROM chu_silver.consultation
        GROUP BY id_consultation HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'hospitalisation', 'id_hospitalisation', COUNT(*)
  FROM (SELECT id_hospitalisation FROM chu_silver.hospitalisation
        GROUP BY id_hospitalisation HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'patient', 'patient_pseudo', COUNT(*)
  FROM (SELECT patient_pseudo FROM chu_silver.patient
        GROUP BY patient_pseudo HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'professionnel', 'identifiant_source', COUNT(*)
  FROM (SELECT identifiant_source FROM chu_silver.professionnel
        GROUP BY identifiant_source HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'diagnostic', 'code_diagnostic', COUNT(*)
  FROM (SELECT code_diagnostic FROM chu_silver.diagnostic
        GROUP BY code_diagnostic HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'etablissement', 'finess', COUNT(*)
  FROM (SELECT finess FROM chu_silver.etablissement
        GROUP BY finess HAVING COUNT(*) > 1) d
  UNION ALL
  SELECT 'satisfaction', 'finess, annee_recueil', COUNT(*)
  FROM (SELECT finess, annee_recueil FROM chu_silver.satisfaction
        WHERE finess IS NOT NULL
        GROUP BY finess, annee_recueil HAVING COUNT(*) > 1) d
) x
ORDER BY table_silver;

-- =====================================================================
-- 8. Partitions présentes : une par année chargée
-- =====================================================================

SHOW PARTITIONS fait_consultation;
SHOW PARTITIONS fait_hospitalisation;
SHOW PARTITIONS fait_deces;
SHOW PARTITIONS fait_satisfaction;

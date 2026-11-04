-- =====================================================================
-- 06_j22_impala_refresh.sql : rendre visibles à Impala les tables Gold
--                             (job J22)
--
-- Moteur  : Impala 2.9, PAS Hive. Dans impala-shell ou dans l’éditeur
--           Impala de Hue. Dans Talend : tImpalaConnection (port 21050),
--           puis un tImpalaRow par instruction.
-- Quand   : après chaque chargement Hive (sql/02 à sql/05)
--
-- Impala garde en cache les métadonnées du metastore :
--   - INVALIDATE METADATA après la création ou la recréation d’une table
--   - REFRESH après un rechargement (nouveaux fichiers, nouvelles
--     partitions) d’une table qu’Impala connaît déjà
--   - COMPUTE STATS donne à Impala ses propres statistiques, qui guident
--     l’ordre de ses jointures
-- Ce script correspond au premier chargement. Aux chargements suivants,
-- remplacer INVALIDATE METADATA par REFRESH, plus léger.
-- =====================================================================

INVALIDATE METADATA chu_dw.dim_temps;
INVALIDATE METADATA chu_dw.dim_patient;
INVALIDATE METADATA chu_dw.dim_professionnel;
INVALIDATE METADATA chu_dw.dim_diagnostic;
INVALIDATE METADATA chu_dw.dim_etablissement;
INVALIDATE METADATA chu_dw.dim_region;
INVALIDATE METADATA chu_dw.fait_consultation;
INVALIDATE METADATA chu_dw.fait_hospitalisation;
INVALIDATE METADATA chu_dw.fait_deces;
INVALIDATE METADATA chu_dw.fait_satisfaction;
INVALIDATE METADATA chu_dw.agg_consultation_mois;
INVALIDATE METADATA chu_dw.agg_hospitalisation_mois;

-- Statistiques d’Impala, table par table
COMPUTE STATS chu_dw.dim_temps;
COMPUTE STATS chu_dw.dim_patient;
COMPUTE STATS chu_dw.dim_professionnel;
COMPUTE STATS chu_dw.dim_diagnostic;
COMPUTE STATS chu_dw.dim_etablissement;
COMPUTE STATS chu_dw.dim_region;
COMPUTE STATS chu_dw.fait_consultation;
COMPUTE STATS chu_dw.fait_hospitalisation;
COMPUTE STATS chu_dw.fait_deces;
COMPUTE STATS chu_dw.fait_satisfaction;
COMPUTE STATS chu_dw.agg_consultation_mois;
COMPUTE STATS chu_dw.agg_hospitalisation_mois;

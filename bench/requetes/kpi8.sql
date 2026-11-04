-- KPI 8 : taux global de satisfaction par région en 2020
--          moyenne des scores pondérée par le nombre de répondants
-- Teste  : élagage de partition, moyenne pondérée, scores absents exclus
SELECT e.nom_region,
       ROUND(SUM(s.score_global * s.nb_repondants) / SUM(s.nb_repondants), 2)
         AS satisfaction_ponderee,
       COUNT(*) AS nb_etablissements
FROM fait_satisfaction s
JOIN dim_etablissement e ON s.id_etablissement = e.id_etablissement
WHERE s.annee = 2020 AND s.nb_repondants > 0 AND s.score_global IS NOT NULL
GROUP BY e.nom_region
ORDER BY satisfaction_ponderee DESC;

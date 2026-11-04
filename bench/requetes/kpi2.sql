-- KPI 2 : taux de consultation par diagnostic en 2019
-- Teste  : élagage de partition, agrégation puis jointure à une petite
--          dimension (map join)
SELECT d.code_diagnostic, d.libelle_diagnostic, c.nb_consultations,
       ROUND(100 * c.nb_consultations / t.total, 2) AS taux_pct
FROM (SELECT id_diagnostic, SUM(nb_consultation) AS nb_consultations
      FROM fait_consultation
      WHERE annee = 2019
      GROUP BY id_diagnostic) c
CROSS JOIN (SELECT SUM(nb_consultation) AS total
            FROM fait_consultation
            WHERE annee = 2019) t
JOIN dim_diagnostic d ON c.id_diagnostic = d.id_diagnostic
ORDER BY taux_pct DESC;

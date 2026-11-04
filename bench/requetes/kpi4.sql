-- KPI 4 : taux d’hospitalisation par diagnostic en 2019
-- Teste  : élagage de partition, agrégation sur les séjours
SELECT d.code_diagnostic, d.libelle_diagnostic, h.nb_hospitalisations,
       ROUND(100 * h.nb_hospitalisations / t.total, 2) AS taux_pct
FROM (SELECT id_diagnostic, SUM(nb_hospitalisation) AS nb_hospitalisations
      FROM fait_hospitalisation
      WHERE annee = 2019
      GROUP BY id_diagnostic) h
CROSS JOIN (SELECT SUM(nb_hospitalisation) AS total
            FROM fait_hospitalisation
            WHERE annee = 2019) t
JOIN dim_diagnostic d ON h.id_diagnostic = d.id_diagnostic
ORDER BY taux_pct DESC;

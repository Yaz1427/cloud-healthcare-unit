-- KPI 2 lu sur la table d’agrégats agg_consultation_mois (chu_dw seulement)
-- Teste  : effet des agrégats, qui remplacent les vues matérialisées.
--          Même résultat que kpi2.sql, sur beaucoup moins de lignes.
SELECT d.code_diagnostic, d.libelle_diagnostic, c.nb_consultations,
       ROUND(100 * c.nb_consultations / t.total, 2) AS taux_pct
FROM (SELECT id_diagnostic, SUM(nb_consultation) AS nb_consultations
      FROM agg_consultation_mois
      WHERE annee = 2019
      GROUP BY id_diagnostic) c
CROSS JOIN (SELECT SUM(nb_consultation) AS total
            FROM agg_consultation_mois
            WHERE annee = 2019) t
JOIN dim_diagnostic d ON c.id_diagnostic = d.id_diagnostic
ORDER BY taux_pct DESC;

-- KPI 1 : taux de consultation par établissement, de mars à juin 2019
-- Teste  : élagage de la partition 2019, filtre sur id_temps, agrégation
--          avant la jointure, total calculé une fois (CROSS JOIN)
SELECT e.finess, e.raison_sociale, c.nb_consultations,
       ROUND(100 * c.nb_consultations / t.total, 2) AS taux_pct
FROM (SELECT id_etablissement, SUM(nb_consultation) AS nb_consultations
      FROM fait_consultation
      WHERE annee = 2019 AND id_temps BETWEEN 20190301 AND 20190630
      GROUP BY id_etablissement) c
CROSS JOIN (SELECT SUM(nb_consultation) AS total
            FROM fait_consultation
            WHERE annee = 2019 AND id_temps BETWEEN 20190301 AND 20190630) t
JOIN dim_etablissement e ON c.id_etablissement = e.id_etablissement
ORDER BY taux_pct DESC;

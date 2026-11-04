-- KPI 5 lu sur la table d’agrégats agg_hospitalisation_mois (chu_dw seulement)
-- Teste  : effet des agrégats. Sexe et tranche d’âge y sont déjà calculés,
--          la jointure avec dim_patient disparaît.
SELECT g.sexe, g.tranche_age, g.nb_hospitalisations,
       ROUND(100 * g.nb_hospitalisations / t.total, 2) AS taux_pct
FROM (SELECT sexe, tranche_age, SUM(nb_hospitalisation) AS nb_hospitalisations
      FROM agg_hospitalisation_mois
      WHERE annee = 2019
      GROUP BY sexe, tranche_age) g
CROSS JOIN (SELECT SUM(nb_hospitalisation) AS total
            FROM agg_hospitalisation_mois
            WHERE annee = 2019) t
ORDER BY g.sexe, g.tranche_age;

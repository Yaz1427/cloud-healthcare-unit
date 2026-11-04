-- KPI 6 : taux de consultation par professionnel en 2019
-- Teste  : élagage de partition, agrégation puis jointure à une dimension
--          de taille moyenne
SELECT pr.identifiant_source, pr.profession, pr.specialite, c.nb_consultations,
       ROUND(100 * c.nb_consultations / t.total, 2) AS taux_pct
FROM (SELECT id_professionnel, SUM(nb_consultation) AS nb_consultations
      FROM fait_consultation
      WHERE annee = 2019
      GROUP BY id_professionnel) c
CROSS JOIN (SELECT SUM(nb_consultation) AS total
            FROM fait_consultation
            WHERE annee = 2019) t
JOIN dim_professionnel pr ON c.id_professionnel = pr.id_professionnel
ORDER BY taux_pct DESC;

-- KPI 3 : taux global d’hospitalisation en 2019
--          patients distincts hospitalisés / patients distincts suivis
-- Teste  : comptage distinct sur deux tables de faits. Le GROUP BY répartit
--          le dédoublonnage entre plusieurs reducers, là où un
--          COUNT(DISTINCT) l’enverrait à un seul. Le membre -1 est exclu.
SELECT h.nb_hospitalises, s.nb_suivis,
       ROUND(100 * h.nb_hospitalises / s.nb_suivis, 2) AS taux_pct
FROM (SELECT COUNT(*) AS nb_hospitalises
      FROM (SELECT id_patient
            FROM fait_hospitalisation
            WHERE annee = 2019 AND id_patient <> -1
            GROUP BY id_patient) a) h
CROSS JOIN (SELECT COUNT(*) AS nb_suivis
            FROM (SELECT u.id_patient
                  FROM (SELECT id_patient FROM fait_consultation
                        WHERE annee = 2019 AND id_patient <> -1
                        UNION ALL
                        SELECT id_patient FROM fait_hospitalisation
                        WHERE annee = 2019 AND id_patient <> -1) u
                  GROUP BY u.id_patient) b) s;

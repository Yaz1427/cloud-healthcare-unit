-- KPI 5 : répartition des hospitalisations de 2019 par sexe et tranche d’âge
-- Teste  : jointure entre deux tables bucketées et triées sur id_patient,
--          que Hive peut convertir en jointure SMB (à vérifier par EXPLAIN).
--          Jointure externe : numérateur et total portent sur les mêmes
--          séjours, les âges manquants forment la tranche « inconnu ».
SELECT g.sexe, g.tranche_age, g.nb_hospitalisations,
       ROUND(100 * g.nb_hospitalisations / t.total, 2) AS taux_pct
FROM (SELECT y.sexe, y.tranche_age,
             SUM(y.nb_hospitalisation) AS nb_hospitalisations
      FROM (SELECT COALESCE(p.sexe, 'I') AS sexe, h.nb_hospitalisation,
                   CASE WHEN h.age_patient IS NULL THEN 'inconnu'
                        WHEN h.age_patient < 18 THEN '0-17'
                        WHEN h.age_patient < 40 THEN '18-39'
                        WHEN h.age_patient < 60 THEN '40-59'
                        WHEN h.age_patient < 75 THEN '60-74'
                        ELSE '75+' END AS tranche_age
            FROM fait_hospitalisation h
            LEFT OUTER JOIN dim_patient p ON h.id_patient = p.id_patient
            WHERE h.annee = 2019) y
      GROUP BY y.sexe, y.tranche_age) g
CROSS JOIN (SELECT SUM(nb_hospitalisation) AS total
            FROM fait_hospitalisation
            WHERE annee = 2019) t
ORDER BY g.sexe, g.tranche_age;

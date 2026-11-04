-- Q9 : consultations de 2019 par mois, région, diagnostic et spécialité
-- Teste  : requête de charge à 4 jointures sur la plus grosse table de
--          faits, le cas du prosit 3 (plus de 3 jointures sur des millions
--          de lignes)
SELECT t.mois, e.nom_region, d.libelle_diagnostic, pr.specialite,
       SUM(f.nb_consultation) AS nb_consultations
FROM fait_consultation f
JOIN dim_temps t          ON f.id_temps = t.id_temps
JOIN dim_etablissement e  ON f.id_etablissement = e.id_etablissement
JOIN dim_diagnostic d     ON f.id_diagnostic = d.id_diagnostic
JOIN dim_professionnel pr ON f.id_professionnel = pr.id_professionnel
WHERE f.annee = 2019
GROUP BY t.mois, e.nom_region, d.libelle_diagnostic, pr.specialite;

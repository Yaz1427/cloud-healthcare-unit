-- KPI 7 : nombre de décès par région en 2019 (lieu du décès)
-- Teste  : élagage de partition. Dans la base « avant », toute la table
--          des décès est lue.
SELECT r.nom_region, SUM(d.nb_deces) AS nb_deces
FROM fait_deces d
JOIN dim_region r ON d.id_region = r.id_region
WHERE d.annee = 2019
GROUP BY r.nom_region
ORDER BY nb_deces DESC;

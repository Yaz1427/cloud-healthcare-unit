# Restitution : livrable 3

Scripts qui complètent la Gold pour la soutenance (satisfaction 2020 et décès 2019), puis l'exportent pour le tableau de bord Power BI.

| Étape | Script | Où | Statut |
|---|---|---|---|
| 1. Extraire décès et satisfaction, enrichir le référentiel des établissements | `01_extraction_s3_s4.sql` | PSQL Tool de pgAdmin | En attente de l'en-tête de `deces.csv` |
| 2. Déposer les trois fichiers dans HDFS | `02_depot_s3_s4.sh` | Terminal de la VM | Prêt |
| 3. Charger dim_etablissement, fait_deces et fait_satisfaction | `03_gold_s3_s4.sql` | Beeline | Prêt |
| 4. Rafraîchir Impala | `sql/06_j22_impala_refresh.sql` | impala-shell | Existant |
| 5. Exporter la Gold pour Power BI | `04_export_powerbi.sh` | Terminal de la VM | Prêt |

Le tableau de bord se construit ensuite avec le kit du dossier [`powerbi/`](../powerbi/GUIDE_POWERBI.md).

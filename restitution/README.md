# Restitution : livrable 3

Scripts qui complètent la Gold pour la soutenance (satisfaction e-Satis 2020 et décès INSEE 2019), puis l'exportent pour le tableau de bord Power BI.

| Étape | Script | Moteur | Ce qu'il fait |
|---|---|---|---|
| Préparation | `convertir_esatis.py` | Python, sur un poste | Fichier Excel e-Satis 48 h MCO → `satisfaction.csv` et `esatis_etablissements.csv` (837 établissements notés en 2020) |
| Tout enchaîner | `00_lancer_s3_s4.sh` | Terminal de la VM | Lance les étapes 1 à 4 et s'arrête à la première erreur |
| 1 | `01_depot_s3_s4.sh` | HDFS | Décès bruts et établissements e-Satis en Bronze, satisfaction en Silver |
| 2 | `02_silver_s3_s4.sql` | Hive (Beeline) | `chu_silver.deces` sans donnée nominative (R2, R6, R10, R12), établissements e-Satis ajoutés à `chu_silver.etablissement` |
| 3 | `03_gold_s3_s4.sql` | Hive (Beeline) | `dim_etablissement` (clés stables), `fait_deces`, `fait_satisfaction` |
| 3 bis | `03_gold_s3_s4_impala.sql` | impala-shell | Métadonnées, statistiques et contrôles du lot |
| 4 | `04_export_powerbi.sh` | impala-shell | Une table par fichier tabulé, archive `export_powerbi.tar.gz` |

## Lancement sur la VM

```bash
cd /home/cloudera && unzip -o kit_s3_s4.zip
sed -i 's/\r$//' kit_s3_s4/restitution/*.sh kit_s3_s4/restitution/*.sql
bash kit_s3_s4/restitution/00_lancer_s3_s4.sh 2>&1 | tee run_s3_s4.log
```

`deces.csv` (fichier de l'INSEE avec son en-tête) reste sur la VM : le script le cherche dans `donnees/`, puis dans `/home/cloudera`. On peut aussi donner son chemin : `DECES=/chemin/deces.csv bash …`. Tout est relançable : chaque étape écrase ce qu'elle a écrit, et un établissement déjà présent n'est jamais ajouté deux fois.

L'archive exportée contient des données pseudonymisées : elle passe par un dossier privé (Drive en accès restreint ou clé USB), jamais par Git ni Discord. Le tableau de bord se construit ensuite avec le kit du dossier [`powerbi/`](../powerbi/GUIDE_POWERBI.md).

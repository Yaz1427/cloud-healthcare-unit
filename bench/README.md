# Benchmark avant/après

Objectif : mesurer ce que rapportent le partitionnement et les leviers qui jouent le rôle d'index dans Hive (buckets triés, Parquet, statistiques, agrégats), puis vérifier le seuil de 2 minutes fixé avec les utilisateurs.

## Configurations comparées

| Configuration | Base | Moteur | Ce qui change |
|---|---|---|---|
| `avant` | `chu_bench_brut` | Hive | Texte brut, sans partition, sans bucket, sans statistiques, conversions de jointure coupées |
| `partitions` (facultatif) | `chu_bench_part` | Hive | Faits partitionnés par année, rien d'autre |
| `apres_hive` | `chu_dw` | Hive | Parquet, partitions, buckets triés, statistiques, map join et jointure SMB |
| `apres_impala` | `chu_dw` | Impala | Même base, moteur interactif sans MapReduce |

Toutes les bases contiennent les mêmes données : `chu_bench_brut` et `chu_bench_part` sont copiées de `chu_dw`.

## Requêtes

| Fichier | Indicateur | Ce qu'elle met à l'épreuve |
|---|---|---|
| `kpi1.sql` | Taux de consultation par établissement, de mars à juin 2019 | Élagage de partition et filtre sur `id_temps` |
| `kpi2.sql` | Taux de consultation par diagnostic | Agrégation puis jointure à une petite dimension |
| `kpi3.sql` | Taux global d'hospitalisation | Patients distincts sur deux tables de faits |
| `kpi4.sql` | Taux d'hospitalisation par diagnostic | Agrégation sur les séjours |
| `kpi5.sql` | Répartition des séjours par sexe et tranche d'âge | Jointure SMB avec `dim_patient` |
| `kpi6.sql` | Taux de consultation par professionnel | Agrégation, dimension de taille moyenne |
| `kpi7.sql` | Décès par région en 2019 | Élagage de partition |
| `kpi8.sql` | Satisfaction par région en 2020 | Moyenne pondérée par les répondants |
| `q9.sql` | Consultations par mois, région, diagnostic et spécialité | 4 jointures sur la plus grosse table de faits |
| `kpi2_agregat.sql`, `kpi5_agregat.sql` | KPI 2 et 5 lus sur les agrégats | Effet des tables d'agrégats (`chu_dw` seulement) |

Les requêtes ne nomment pas la base : elle est choisie à la connexion, par l'URL JDBC de Beeline ou l'option `-d` d'impala-shell. Les années de référence sont 2019, et 2020 pour la satisfaction : à adapter si DATA 2024 couvre d'autres années.

## Protocole

1. Charger `chu_dw` en entier (README principal, étapes 1 à 6).
2. Créer les bases de comparaison :
   ```bash
   HIVE="beeline -u jdbc:hive2://quickstart.cloudera:10000 -n cloudera"
   $HIVE -f bench/00_base_avant.sql
   $HIVE -f bench/01_base_partitions.sql      # facultatif
   ```
3. Sur un seul PC, le plus puissant du groupe : redémarrer la VM, arrêter les services inutiles dans Cloudera Manager (HBase, Oozie, Spark, Solr...), puis lancer les mesures, par exemple la nuit :
   ```bash
   bash bench/run_bench.sh 5
   bash bench/run_bench.sh 5 "avant partitions apres_hive apres_impala"   # avec la base intermédiaire
   ```
4. Enregistrer les plans d'exécution : `bash bench/explain.sh`
5. Sur le PC Windows (Python 3 et matplotlib), produire la synthèse et le graphique :
   ```bash
   python bench/graphiques.py resultats/benchmark/mesures_<horodatage>.csv
   python bench/graphiques.py resultats/benchmark/mesures_<horodatage>.csv --log
   ```
6. Dans le rapport : la synthèse, le graphique, et pour chaque écart sa cause, preuve à l'appui dans les plans (partitions lues, type de jointure). Dire aussi quand un levier ne gagne rien.

La durée retenue est la médiane des exécutions, moins sensible qu'une moyenne à une exécution perturbée. Note la configuration de la VM (mémoire, processeurs) et les volumes chargés dans le rapport : sans eux, les durées ne veulent rien dire.

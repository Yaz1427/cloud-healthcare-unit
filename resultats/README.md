# Résultats

Ce dossier ne contient que des agrégats : durées, comptages, pourcentages et plans d'exécution. Jamais une ligne de données, un identifiant de patient ou un nom.

## Maquette du livrable 2 (nuit du 6 au 7 novembre 2026)

`notes_maquette.txt` liste les réglages de l'environnement et l'incident de la VM relevés pendant la maquette.

### benchmark/

- `mesures_<horodatage>.csv` : toutes les exécutions d'un lancement de `bench/run_bench.sh`, à l'heure de la VM. Il y en a quatre : le premier (configurations « avant » et « après, Impala »), puis trois pour la configuration « après, Hive », dont un avec deux requêtes en erreur et une mesure prise sur une VM saturée
- `mesures_retenues.csv` : les quinze mesures retenues, une par requête et par configuration
- `synthese_retenues.csv` et `avant_apres_retenues.png` : durées, gains et graphique, produits par `python3 bench/graphiques.py resultats/benchmark/mesures_retenues.csv --log`
- `explain/` : plans d'exécution de KPI 2, KPI 5 et Q9 (Hive et Impala), produits par `bench/explain.sh`

### qualite/

- `comptages_extraction.txt` : lignes exportées par `chargement/01_extraction_s1.sql`
- `qualite_source.csv` : complétude, validité, FINESS, doublons et références absentes, mesurés à la source par `chargement/03_qualite_source.sql`
- `j30_gold_impala.csv` : sections 2, 3, 4 et 8 de J30 sur la Gold, exécutées par Impala (`chargement/04_controles_gold.sql`)

## Pour un nouveau chargement

Le contrôle complet reste `sql/07_j30_controles_qualite.sql` :

```bash
beeline -u jdbc:hive2://quickstart.cloudera:10000 -n cloudera --force=true \
  --outputformat=csv2 -f sql/07_j30_controles_qualite.sql \
  > resultats/qualite/j30_$(date +%Y-%m-%d).csv
```

Le fichier enchaîne les tableaux des huit sections de `sql/07`, chacun précédé de sa ligne d'en-tête.

Les journaux `journal_<horodatage>.log` du benchmark restent en local : ils servent à comprendre une erreur, pas au rapport.

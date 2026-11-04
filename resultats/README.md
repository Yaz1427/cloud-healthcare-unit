# Résultats

Ce dossier ne contient que des agrégats : durées, comptages, pourcentages. Jamais une ligne de données, un identifiant de patient ou un nom.

## benchmark/

- `mesures_<horodatage>.csv` : toutes les exécutions, écrites par `bench/run_bench.sh`
- `synthese_<horodatage>.csv` et `avant_apres_<horodatage>.png` : médianes, gains et graphique, produits par `bench/graphiques.py`
- `explain/` : plans d'exécution de chaque requête, produits par `bench/explain.sh`

Les journaux `journal_<horodatage>.log` restent en local : ils servent à comprendre une erreur, pas au rapport.

## qualite/

Sorties des contrôles J30, à enregistrer à chaque chargement :

```bash
beeline -u jdbc:hive2://quickstart.cloudera:10000 -n cloudera --force=true \
  --outputformat=csv2 -f sql/07_j30_controles_qualite.sql \
  > resultats/qualite/j30_$(date +%Y-%m-%d).csv
```

Le fichier enchaîne les tableaux des huit sections de `sql/07`, chacun précédé de sa ligne d'en-tête. Les comptages de rejets par règle se font à part (voir `talend/README.md`).

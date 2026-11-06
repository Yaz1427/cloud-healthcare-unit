# Chargement de la Silver sans Talend

Chemin de secours utilisé pour la maquette du livrable 2 : les règles de nettoyage et la pseudonymisation des jobs J10 à J13 sont appliquées en SQL dans PostgreSQL, puis les fichiers sont déposés dans HDFS. Les tables Silver de `sql/01_silver_ddl.sql` les lisent telles quelles.

| Étape | Script | Où |
|---|---|---|
| 1. Extraire DATA 2024 en fichiers Silver | `01_extraction_s1.sql` | PSQL Tool de pgAdmin, base `data2024` |
| 2. Déposer les fichiers dans HDFS | `02_depot_hdfs.sh` | Terminal de la VM, racine du dépôt |
| 3. Mesurer la qualité à la source | `03_qualite_source.sql` | PSQL Tool de pgAdmin, base `data2024` |
| 4. Contrôler la Gold (sections 2, 3, 4 et 8 de J30) | `04_controles_gold.sql` | impala-shell, dans la VM |

## 1. Extraction (PostgreSQL)

Avant : créer `C:\chu\silver` et copier `DATA 2024\Hospitalisation\Hospitalisations.csv` dans `C:\chu\sources`.

```text
\set sel 'un_secret_que_tu_choisis'
\i 'C:/chu/chargement/01_extraction_s1.sql'
```

Le sel n'est écrit dans aucun fichier : il ne vit que le temps de la session psql. Sans lui, le script s'arrête. Tous les objets créés sont temporaires.

Sorties : `patient.csv`, `professionnel.csv`, `diagnostic.csv`, `consultation.csv`, `hospitalisation.csv` et `etablissement.csv`, au format du contrat Silver (point-virgule, sans en-tête, UTF-8, dates `yyyy-MM-dd`, champ vide pour NULL).

## 2. Dépôt dans HDFS (VM)

Copier les six CSV (et, si besoin, `ref_departement.csv`, `ref_region.csv` et `Hospitalisations.csv`) dans `/home/cloudera/chu_data`, puis :

```bash
bash chargement/02_depot_hdfs.sh /home/cloudera/chu_data 2>&1 | tee logs/05_depot_hdfs.log
```

## Écarts avec le livrable 1, constatés sur DATA 2024

- Les hospitalisations sont un fichier CSV et non une table de la base : elles sont lues par `\copy`.
- `Consultation` ne porte pas de FINESS : les consultations sont rattachées à l'établissement inconnu (-1) en Gold.
- Le référentiel des établissements est réduit aux FINESS présents dans les séjours. Le département vient des deux premiers caractères du FINESS (`97` suivi du 4e caractère pour l'outre-mer).
- `Patient.Date` (naissance) est un texte au format M/J/AAAA. `Date_Entree` est au format JJ/MM/AAAA.
- Satisfaction (S3) et décès (S4) ne sont pas chargés dans cette maquette : leurs dossiers Silver restent vides.

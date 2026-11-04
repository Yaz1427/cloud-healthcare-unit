# Jobs Talend

Les jobs sont développés dans Talend Open Studio for Big Data 7.3.1, chacun sur son poste, puis exportés dans `talend/export/`.

## Les jobs de la chaîne

| Job | Rôle | Écrit dans |
|---|---|---|
| J00_orchestrateur | Lance la chaîne dans l'ordre, arrête tout à la première erreur | Journal du chargement |
| J01_ingest_postgresql | Extrait les tables utiles de DATA 2024, sans colonne identifiante (R10) | `/datalake/bronze/postgresql/<date>/` |
| J02_ingest_etablissements | Copie le référentiel des établissements tel quel | `/datalake/bronze/etablissements/<date>/` |
| J03_ingest_satisfaction | Copie les fichiers de satisfaction tels quels | `/datalake/bronze/satisfaction/<date>/` |
| J04_ingest_deces | Copie les fichiers des décès de l'INSEE tels quels | `/datalake/bronze/deces/<date>/` |
| J05_ref_cog | Réduit les fichiers du COG aux codes et libellés | `/datalake/referentiels/cog_insee/` |
| J10_silver_actes | Patients, consultations, séjours, diagnostics, professionnels | `/datalake/silver/<table>/` |
| J11_silver_etablissement | Établissements et département | `/datalake/silver/etablissement/` |
| J12_silver_satisfaction | Notes de satisfaction | `/datalake/silver/satisfaction/` |
| J13_silver_deces | Décès sans aucune donnée nominative | `/datalake/silver/deces/` |
| J20_gold_dimensions | Instructions de `sql/03`, une par tHiveRow | `chu_dw` |
| J21_gold_faits | Instructions de `sql/04` puis `sql/05`, une par tHiveRow | `chu_dw` |
| J22_impala_refresh | Instructions de `sql/06`, une par tImpalaRow | Métadonnées d'Impala |
| J30_controle_qualite | Requêtes de `sql/07` | Rapport du chargement |

## Ce que les jobs Silver doivent produire

Les colonnes et leur ordre sont fixés par `sql/01_silver_ddl.sql` : c'est le contrat avec la Gold.

- tHDFSOutput, action « Écraser », séparateur point-virgule, sans en-tête, encodage UTF-8.
- Dates au format `yyyy-MM-dd`. Valeur absente : champ vide, lu comme NULL par Hive.
- `date_chargement` : la date du chargement, prise dans le contexte.
- Si un texte peut contenir un point-virgule (une raison sociale, par exemple), le retirer dans le tMap ou changer de séparateur, ici et dans `sql/01`.
- Pseudonymisation (R9) dans le premier tMap, avant toute écriture en Silver. Remplace `row1.id_patient` par la vraie colonne :
  ```java
  row1.id_patient == null || row1.id_patient.trim().isEmpty() ? null
      : org.apache.commons.codec.digest.DigestUtils.sha256Hex(context.sel + row1.id_patient.trim())
  ```
  Si Talend ne trouve pas la classe, ajouter un tLibraryLoad avec le jar commons-codec. L'identifiant source n'est écrit ni en Silver ni dans les rejets.

## Rejets

- Écrits dans `/datalake/rejets/<job>/<AAAA-MM-JJ>/`, au format CSV avec séparateur point-virgule.
- Les deux premières colonnes sont `regle` et `motif` (par exemple `R3` et `doublon exact`), puis viennent les colonnes d'origine.
- Jamais l'identifiant patient source (remplacé par `patient_pseudo`), jamais le nom d'une personne décédée.

Pour compter les rejets par règle et par motif, dans la VM :

```bash
hdfs dfs -cat /datalake/rejets/J10_silver_actes/2026-11-05/* | cut -d';' -f1,2 | sort | uniq -c
```

## Contexte

`contexts/chu.properties.example` est le modèle : copie-le en `contexts/chu.properties` (ignoré par Git), remplis-le, et charge-le au lancement avec tFileInputProperties puis tContextLoad. Aucun mot de passe ni sel n'est écrit en dur dans un job.

## Écrire dans HDFS depuis Windows

Si Talend n'arrive pas à écrire dans HDFS (délai dépassé, ou « could only be replicated to 0 nodes ») :

1. dans `C:\Windows\System32\drivers\etc\hosts`, associer l'adresse IP de la VM au nom `quickstart.cloudera` ;
2. dans le tHDFSConnection, ajouter la propriété Hadoop `dfs.client.use.datanode.hostname` avec la valeur `true`.

## Exporter et importer les jobs

- **Exporter** : clic droit sur ses jobs, Export items, Select archive file, en cochant l'export des dépendances. Nommer l'archive d'après ses jobs, par exemple `talend/export/J01_J10_postgresql.zip`, puis la commiter à chaque version qui fonctionne.
- **Importer** sur la machine de référence : Import items, Select archive file.

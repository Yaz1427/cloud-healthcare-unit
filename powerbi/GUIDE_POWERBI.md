# Construire le tableau de bord CHU dans Power BI Desktop

Ce guide construit, étape par étape, le tableau de bord de la soutenance : 6 pages pour la direction et les praticiens, plus 2 pages techniques. Il suit la maquette du PROSIT RETOUR 4, adaptée aux données réellement chargées. Compte 3 à 4 heures la première fois.

> **Si le temps manque**, dans cet ordre : parties 1 à 4 (données, modèle, mesures, thème), puis les pages 1, 4, 5 et 6, puis les pages 2 et 3 ; les signets, le rôle de démonstration, la page d'extraction et le graphe paramétrable en dernier. Ce qui n'est pas construit n'est pas montré : prévenir celui qui présente, pour qu'il saute la phrase correspondante du dossier de soutenance.

## 0. Ce qu'il te faut

| Élément | Où |
|---|---|
| Power BI Desktop à jour, en français | Microsoft Store ou site de Microsoft (gratuit, Windows seulement) |
| Le dossier `donnees_powerbi` | Les fichiers `.tsv` de l'archive `export_powerbi.tar.gz` exportée de la VM (dans PowerShell : `tar -xzf export_powerbi.tar.gz`), plus `ref_departement.csv`, `ref_region.csv` et `population_region_2019.csv` |
| Les fichiers de ce dossier `powerbi/` | `requetes_powerquery.m`, `mesures.dax`, `mesures_vue_requete_dax.dax`, `theme_chu.json`, `regions_france.topojson` |

Mets tout le contenu de `donnees_powerbi` dans un seul dossier, par exemple `C:\chu\donnees_powerbi`.

> Les fichiers `.tsv` contiennent des données pseudonymisées : ils restent sur ton PC, jamais dans Git ni sur un canal public.

## 1. Préparer le fichier

1. Ouvre Power BI Desktop, puis **Fichier > Options et paramètres > Options**.
2. **Fichier actif > Chargement des données** : décoche **Date/heure automatique** (sinon Power BI crée une table de dates cachée par colonne de date).
3. **Global > Sécurité** : coche l'utilisation des visuels **Azure Maps**, s'il y a la case. **Global > Fonctionnalités en préversion** : coche **Visuel de carte de formes** (plan B des cartes, partie 6.7).
4. Enregistre tout de suite : `CHU_tableau_de_bord.pbix`.

## 2. Importer les données

### 2.1 Le paramètre du dossier

**Accueil > Transformer les données** ouvre Power Query. Puis **Accueil > Gérer les paramètres > Nouveau paramètre** :

- Nom : `DossierDonnees`
- Type : Texte
- Valeur actuelle : `C:\chu\donnees_powerbi` (sans `\` à la fin)

### 2.2 Les requêtes

Le fichier `requetes_powerquery.m` contient une requête par bloc. Pour chacune : **Accueil > Nouvelle source > Requête vide**, **Éditeur avancé**, colle le bloc, **Terminé**, puis renomme la requête (clic droit > Renommer) exactement comme dans l'en-tête du bloc. Dans cet ordre :

1. `LireExport` (une fonction)
2. `cog_departement`
3. `dim_temps`, `dim_patient`, `dim_professionnel`, `dim_diagnostic`, `dim_etablissement`, `dim_region`
4. `fait_consultation`, `fait_hospitalisation`, `fait_deces`, `fait_satisfaction`
5. `Actualisation`

Clic droit sur `LireExport` et sur `cog_departement` > décoche **Activer le chargement** : elles servent aux autres requêtes, pas au modèle.

Pourquoi des requêtes écrites à la main plutôt que l'assistant « Texte/CSV » : la détection automatique des types ferait perdre le zéro des codes (« 01 » deviendrait 1), et un Power BI en français lirait mal les décimales à point des scores de satisfaction.

### 2.3 Charger et vérifier

**Accueil > Fermer et appliquer**. Le chargement prend une à deux minutes (un million de consultations et un million de professionnels). Vérifie ensuite le nombre de lignes de chaque table dans la vue **Données** (en bas à gauche de chaque table) :

| Table | Lignes attendues |
|---|---|
| fait_consultation | 1 027 157 |
| fait_hospitalisation | 2 479 |
| dim_patient | 100 001 |
| dim_professionnel | 1 048 576 |
| dim_diagnostic | 15 491 |
| dim_temps | 11 323 |
| dim_region | 19 |

Les nombres de lignes des décès, de la satisfaction et des établissements, et les valeurs attendues des cartes KPI, sont dans `controle_export.txt`, établi à partir des contrôles Impala du chargement.

## 3. Le modèle

### 3.1 Les relations

Ouvre la vue **Modèle**. Supprime toute relation créée automatiquement par Power BI, puis crée celles-ci avec **Modélisation > Gérer les relations > Nouveau**. Toutes sont en **Plusieurs à un (*:1)**, direction du filtrage croisé **Unique**, et actives :

| Table « plusieurs » | Colonne | Table « un » | Colonne |
|---|---|---|---|
| fait_consultation | id_temps | dim_temps | id_temps |
| fait_consultation | id_patient | dim_patient | id_patient |
| fait_consultation | id_professionnel | dim_professionnel | id_professionnel |
| fait_consultation | id_diagnostic | dim_diagnostic | id_diagnostic |
| fait_consultation | id_etablissement | dim_etablissement | id_etablissement |
| fait_hospitalisation | id_temps | dim_temps | id_temps |
| fait_hospitalisation | id_patient | dim_patient | id_patient |
| fait_hospitalisation | id_diagnostic | dim_diagnostic | id_diagnostic |
| fait_hospitalisation | id_etablissement | dim_etablissement | id_etablissement |
| fait_deces | id_temps | dim_temps | id_temps |
| fait_deces | id_region | dim_region | id_region |
| fait_satisfaction | id_temps | dim_temps | id_temps |
| fait_satisfaction | id_etablissement | dim_etablissement | id_etablissement |

Les relations vers `dim_tranche_age` viennent en 3.3, après la création des colonnes.

Pourquoi pas de filtrage bidirectionnel : il crée des chemins de filtre ambigus entre les faits et ralentit les visuels. Pourquoi la région du patient est une colonne de `dim_patient` et non une relation vers `dim_region` : `fait_hospitalisation` serait alors atteint par deux chemins (le patient et l'établissement), et Power BI désactiverait l'un des deux.

### 3.2 Les réglages de tables

- **dim_temps** : sélectionne la table, **Outils de table > Marquer comme table de dates**, colonne `date_complete`. Sans ça, les comparaisons à l'année précédente se trompent. Puis sélectionne `libelle_mois` > **Outils de colonne > Trier par colonne > mois**.
- **Hiérarchie de dates** : dans le volet Données, clic droit sur `annee` > **Créer une hiérarchie**, puis ajoute `trimestre`, `libelle_mois` et `date_complete`.
- **Masquer les clés** : dans la vue Modèle, masque (icône d'œil) toutes les colonnes `id_*` des faits, et `annee` des faits. Elles ne servent qu'aux relations. Masquer n'est pas protéger : la sécurité est en partie 8.
- **Catégories géographiques** : `dim_region[nom_region]`, `dim_etablissement[nom_region]` et `dim_patient[nom_region_patient]` > **Outils de colonne > Catégorie de données > État ou province** ; les colonnes `pays` > **Pays/région**.

### 3.3 Tables et colonnes calculées

Le fichier `mesures.dax` contient tout le code. Dans l'ordre :

1. **Modélisation > Nouvelle table** : `_Mesures`, puis `dim_tranche_age`. Dans `dim_tranche_age`, trie `tranche_age` par `ordre` (**Trier par colonne**).
2. **Nouvelle colonne** (en sélectionnant d'abord la bonne table) : `tranche_age` dans `fait_consultation`, `fait_hospitalisation` et `fait_deces` ; `avec_donnees` dans `dim_temps` ; `etablissement` dans `dim_etablissement`.
3. Trois relations de plus, **Plusieurs à un**, **Unique** : `fait_consultation[tranche_age]`, `fait_hospitalisation[tranche_age]` et `fait_deces[tranche_age]` vers `dim_tranche_age[tranche_age]`. Masque ensuite les trois colonnes `tranche_age` des faits.

### 3.4 Les mesures

Sélectionne `_Mesures`, puis pour chaque mesure de `mesures.dax` (parties 3 à 5) : **Nouvelle mesure**, colle le code, **Entrée**. Plus rapide : `mesures_vue_requete_dax.dax` crée les 28 mesures d'un seul collage dans la **vue Requête DAX** (mode d'emploi en tête du fichier) ; `Titre analyse` se crée ensuite à la main, en partie 7.4. Ensuite, supprime la colonne `Masquer` de `_Mesures` : la table passe en tête du volet Données, avec l'icône de calculatrice.

Formats, avec **Outils de mesure > Format** :

| Mesures | Format |
|---|---|
| Nb consultations, Nb hospitalisations, Nb décès, Patients hospitalisés, Patients suivis, Décès 2019, Population 2019, Répondants 2020, Établissements notés 2020, les N-1 | Nombre entier, séparateur de milliers |
| Tous les « Taux », Part des hospitalisations, les deux « Évolution » | Pourcentage, 1 décimale |
| Satisfaction pondérée, Satisfaction 2020, Durée moyenne séjour, Âge moyen au décès, Décès 2019 pour 100 000 hab. | Décimal, 1 décimale |

## 4. Le thème et la page

1. **Affichage > Thèmes > Parcourir les thèmes** > `theme_chu.json` : couleurs, polices et fond gris clair des pages.
2. Taille de page : **Format de page > Paramètres du canevas**, 16:9.
3. Gabarit commun à chaque page, aux mêmes positions :
   - en haut à gauche, un **titre-message** (une zone de texte ou une carte qui affiche une mesure de titre) : une phrase qui dit ce qu'il faut retenir, pas le nom de la page ;
   - en haut à droite, les **segments** ;
   - en bas, la **barre de navigation** (partie 7.2).

Règles des visuels : barres triées, axes qui partent de zéro, pas de 3D, unité et période dans chaque titre, au plus 6 à 8 visuels par page.

## 5. Les 6 pages

Pour chaque page : le message qu'elle porte, puis ses visuels. Les noms de champs sont ceux du volet Données.

### Page 1 : Synthèse direction (page d'accueil)

Message : en 5 secondes, l'activité, la part de patients hospitalisés, la satisfaction et la mortalité par région.

| Visuel | Champs | Réglages |
|---|---|---|
| Carte (titre-message) | `[Titre synthèse]` | Sans titre ni étiquette de catégorie, police 18 |
| Segment | `dim_temps[annee]` | Style **Liste déroulante**, sélection unique |
| Carte | `[Actualisé le]` de la table Actualisation | Petite, en haut à droite |
| 5 cartes KPI | `[Nb consultations]`, `[Nb hospitalisations]`, `[Taux global hospitalisation]`, `[Satisfaction 2020]`, `[Décès 2019]` | Les deux premières avec `[Évolution consultations]` et `[Évolution hospitalisations]` dans une carte à plusieurs lignes ou dans l'info-bulle |
| Graphique en courbes et histogramme groupé | Axe : hiérarchie de dates au niveau mois ; Colonnes : `[Nb consultations]` ; Courbe : `[Nb hospitalisations]` | Courbe sur l'**axe secondaire** : les deux volumes n'ont pas la même échelle |
| Carte (Azure Maps) | Emplacement : `dim_etablissement[nom_region]` et `dim_etablissement[pays]` ; couleur : `[Satisfaction 2020]` | Couche de carte remplie, dégradé de couleur sur la mesure (partie 6.7) |
| Graphique à barres groupées | Axe : `dim_diagnostic[libelle_diagnostic]` ; Valeur : `[Nb consultations]` | Filtre du visuel : **N premiers**, 10, par `[Nb consultations]` ; titre « Top 10 des diagnostics en consultation » |
| Histogramme groupé | Axe : `dim_tranche_age[tranche_age]` ; Légende : `dim_patient[sexe]` ; Valeur : `[Part des hospitalisations]` | Titre « Répartition des hospitalisations par âge et par sexe » |

Le signet de la carte (satisfaction ↔ décès) est en partie 7.1.

### Page 2 : Activité des consultations

Message : de quoi souffrent les patients qui consultent, et quand.

| Visuel | Champs | Réglages |
|---|---|---|
| Segments | `dim_temps[annee]`, `dim_patient[nom_region_patient]`, `dim_professionnel[specialite]` | Synchronisés avec la page 1 pour l'année (partie 7.3) |
| Barres | Axe `dim_diagnostic[libelle_diagnostic]`, valeur `[Taux consultation diagnostic]` (KPI 2) | Top 10 ; info-bulle : `[Nb consultations]` |
| Barres | Axe `dim_professionnel[specialite]`, valeur `[Taux consultation professionnel]` (KPI 6) | Triées décroissantes |
| Matrice | Lignes `dim_temps[libelle_mois]`, colonnes `dim_temps[annee]`, valeur `[Nb consultations]` | **Mise en forme conditionnelle > Couleur d'arrière-plan**, dégradé : les mois atypiques ressortent |
| Carte (Azure Maps) ou barres | `dim_patient[nom_region_patient]`, `[Nb consultations]` | Titre « Consultations par région de domicile du patient » |
| Graphe paramétrable | Partie 7.4 | |
| Zone de texte | « Taux par établissement (KPI 1) : non calculable. La base source ne relie pas les consultations à un établissement (aucun FINESS). » | En petit, sous les barres : c'est un constat à montrer, pas à cacher |

### Page 3 : Hospitalisations

Message : qui est hospitalisé, pour quoi, et combien de temps.

Pas de segment Professionnel sur cette page : il ne filtrerait que les consultations et fausserait le dénominateur du KPI 3.

| Visuel | Champs | Réglages |
|---|---|---|
| Segments | `dim_temps[annee]`, `dim_patient[nom_region_patient]`, `dim_diagnostic[lettre_code]` | |
| Cartes KPI | `[Taux global hospitalisation]` (KPI 3), `[Nb hospitalisations]` avec `[Évolution hospitalisations]`, `[Durée moyenne séjour]` | |
| Courbe | Axe : hiérarchie de dates (mois), valeur `[Nb hospitalisations]` | |
| Barres | Axe `dim_diagnostic[libelle_diagnostic]`, valeur `[Taux hospitalisation diagnostic]` (KPI 4) | Top 10 |
| Histogramme groupé | Axe `dim_tranche_age[tranche_age]`, légende `dim_patient[sexe]`, valeur `[Part des hospitalisations]` (KPI 5) | Étiquettes de données au format pourcentage |
| Barres | Axe `dim_etablissement[nom_region]`, valeur `[Nb hospitalisations]` | Titre « Séjours par région de l'établissement » |

### Page 4 : Décès en 2019 par région

Message : où l'on meurt le plus en 2019, en nombre et rapporté à la population.

Aucun segment d'année : les mesures sont figées sur 2019, et l'année est écrite dans chaque titre. Le segment de la page 1 ne s'applique pas ici (partie 7.3).

| Visuel | Champs | Réglages |
|---|---|---|
| Carte (titre-message) | `[Titre décès]` | |
| Barres | Axe `dim_region[nom_region]`, valeur `[Décès 2019]` | Triées ; titre « Décès en 2019 par région (effectifs, non rapportés à la population) » : visuel principal |
| Carte (Azure Maps) | Emplacement `dim_region[nom_region]` et `dim_region[pays]`, couleur `[Décès 2019 pour 100 000 hab.]` | Titre « Décès en 2019 pour 100 000 habitants, par région du lieu de décès » |
| Histogramme groupé | Axe `dim_tranche_age[tranche_age]`, légende `fait_deces[sexe]`, valeur `[Décès 2019]` | Les décès ne sont pas reliés à `dim_patient` : on prend le sexe de `fait_deces` |
| Courbe | Axe `dim_temps[date_complete]` au niveau mois, valeur `[Nb décès]` | Filtre du visuel : `dim_temps[annee]` de 2015 à 2019 ; montre la saisonnalité (pics d'hiver) |

Deux mises en garde à écrire sous les visuels : on compte le lieu du décès, pas la résidence (une région dotée de grands hôpitaux reçoit des malades venus d'ailleurs) ; et le taux pour 100 000 habitants n'est pas standardisé par âge (une région âgée a mécaniquement plus de décès).

### Page 5 : Satisfaction en 2020 par région

Message : où les patients hospitalisés sont le moins satisfaits.

| Visuel | Champs | Réglages |
|---|---|---|
| Carte (Azure Maps) | Emplacement `dim_etablissement[nom_region]` et `pays`, couleur `[Satisfaction 2020]` | Info-bulles : `[Répondants 2020]`, `[Établissements notés 2020]` |
| Barres | Axe `dim_etablissement[nom_region]`, valeur `[Satisfaction 2020]` | Triées croissantes : les régions à surveiller en haut |
| Tableau | `dim_etablissement[etablissement]`, `[Satisfaction 2020]`, `[Répondants 2020]` | Filtré par la région cliquée sur la carte ; trié par score croissant |
| Nuage de points | Valeurs `dim_etablissement[etablissement]`, axe X `[Répondants 2020]`, axe Y `[Satisfaction 2020]` | Repère les scores fondés sur peu de répondants |

Le score est celui d'e-Satis (HAS), sur 100, ajusté par la HAS ; la moyenne régionale est pondérée par le nombre de répondants.

### Page 6 : Vue praticien

Message : pour mon diagnostic ou ma spécialité, quels patients et quelles hospitalisations.

| Visuel | Champs | Réglages |
|---|---|---|
| Segments | `dim_temps[annee]`, `dim_professionnel[specialite]`, `dim_diagnostic[libelle_diagnostic]` (avec recherche) | Dans le segment de diagnostic : **Paramètres du segment > Recherche** |
| Barres | Top 10 `dim_diagnostic[libelle_diagnostic]` par `[Nb consultations]` | |
| Barres | Top 10 `dim_diagnostic[libelle_diagnostic]` par `[Nb hospitalisations]` | |
| Histogramme groupé | `dim_tranche_age[tranche_age]`, `dim_patient[sexe]`, `[Part des hospitalisations]` | Profil des patients hospitalisés pour le diagnostic choisi |
| Cartes KPI | `[Nb consultations]`, `[Nb hospitalisations]`, `[Durée moyenne séjour]` | |

Le détail par professionnel (KPI 6 au niveau individuel) reste réservé à la direction : la vue praticien s'arrête à la spécialité.

### Pages techniques

- **Détail diagnostic** (page d'extraction, masquée) : dans le volet de la page, mets `dim_diagnostic[libelle_diagnostic]` dans **Extraction**. Contenu : cartes `[Nb consultations]`, `[Nb hospitalisations]`, `[Durée moyenne séjour]`, histogramme âge et sexe, courbe mensuelle. Un clic droit sur un diagnostic, dans n'importe quelle page, propose **Extraire > Détail diagnostic**.
- **Info-bulle région** (masquée) : **Format de page > Informations sur la page > Autoriser l'utilisation en tant qu'info-bulle**, taille **Info-bulle**. Contenu : `[Décès 2019]`, `[Décès 2019 pour 100 000 hab.]`, `[Satisfaction 2020]`, `[Répondants 2020]`. Puis, sur les cartes des pages 1, 4 et 5 : **Format > Info-bulles > Type : Page de rapport**, page « Info-bulle région ».

## 6. Les cartes géographiques

### 6.1 Azure Maps, couche remplie

1. Ajoute le visuel **Azure Maps** (volet Visualisations).
2. **Emplacement** : la colonne de région, puis la colonne `pays` (« France » aide le géocodage et évite qu'une région soit cherchée dans un autre pays).
3. **Format > Couche de carte remplie** (ou « Bulle », selon la version) : active-la, puis colore le remplissage avec **fx** (mise en forme conditionnelle), dégradé sur la mesure.
4. Les DROM tirent la carte vers le large : zoome sur la métropole et garde-les dans les barres triées de la même page.

### 6.2 Plan B, carte de formes

Si Azure Maps est indisponible ou si le géocodage se trompe : visuel **Carte de formes** (préversion activée en partie 1), **Format > Forme de la carte > Ajouter une carte**, fichier `regions_france.topojson` (13 régions de métropole). **Afficher les clés de carte** : les noms de région du fichier sont ceux du COG, avec accents. Emplacement : la colonne de région ; saturation de couleur : la mesure.

### 6.3 Plan C

Des barres triées par région : moins spectaculaires, mais elles montrent aussi les DROM et ne dépendent d'aucun service.

## 7. Interactivité

### 7.1 Signets : satisfaction ou décès sur la synthèse

1. Superpose sur la page 1 deux cartes de même taille, à la même place : satisfaction 2020 et décès 2019 pour 100 000 habitants.
2. **Affichage > Sélection** : masque la carte des décès, puis **Affichage > Signets > Ajouter**, nom « Synthèse satisfaction ». Masque la satisfaction, affiche les décès, ajoute « Synthèse décès ».
3. Pour chaque signet : **…** > décoche **Données**, pour que la bascule ne réinitialise pas le segment d'année.
4. **Insérer > Boutons > Navigateur > Navigateur de signets** au-dessus de la carte : deux boutons « Satisfaction » et « Décès ».

### 7.2 Navigation

**Insérer > Boutons > Navigateur > Navigateur de pages** en bas de chaque page (les pages masquées n'y figurent pas). Ctrl + clic pour tester dans Desktop.

### 7.3 Synchroniser les segments

**Affichage > Synchroniser les segments** : le segment d'année est synchronisé entre les pages 1, 2, 3 et 6, pas sur les pages 4 et 5, dont l'année est fixée. Sur la page 1, **Format > Modifier les interactions** : le segment d'année n'agit pas sur la carte de satisfaction ni sur le KPI des décès (leurs mesures sont figées, mais on évite l'icône de filtre trompeuse).

### 7.4 Le graphe paramétrable

1. **Modélisation > Nouveau paramètre > Champs** : nom « Axe analyse », coche `dim_patient[nom_region_patient]`, `dim_diagnostic[libelle_diagnostic]`, `dim_professionnel[specialite]`, `dim_patient[sexe]`, `dim_tranche_age[tranche_age]`, `dim_temps[libelle_mois]`. Laisse « Ajouter un segment » coché.
2. Même chose pour « Mesure analyse » avec `[Nb consultations]`, `[Nb hospitalisations]`, `[Durée moyenne séjour]`.
3. Un histogramme : axe « Axe analyse », valeur « Mesure analyse ». Titre : **fx** > valeur du champ `[Titre analyse]`.
4. Les deux segments en **sélection unique**, en-tête masqué (pour éviter la gomme qui vide la sélection).

Un seul visuel remplace 6 axes × 3 mesures = 18 graphiques, sans aucune vue de plus dans Hive : le modèle porte déjà les relations, et l'agrégation se fait en mémoire.

## 8. Sécurité : un rôle de démonstration

**Modélisation > Gérer les rôles > Nouveau** :

- Rôle « Direction » : aucun filtre.
- Rôle « Praticien cardiologie » : table `dim_professionnel`, filtre DAX `[specialite] = "Cardiologie"` (prends une spécialité qui existe dans tes données).

Teste avec **Modélisation > Afficher en tant que > Praticien cardiologie** : les consultations ne montrent plus que cette spécialité. En production, le rôle Praticien filtrerait les établissements de rattachement du praticien, à partir d'une table d'habilitations tenue par le SI (PROSIT RETOUR 4, partie 9) ; nos consultations n'ayant pas de FINESS, la démo filtre par spécialité.

## 9. Performance : la preuve pour la soutenance

**Optimiser > Analyseur de performances > Démarrer l'enregistrement**, puis **Actualiser les visuels** sur la page 1. Chaque visuel affiche sa durée (requête DAX, affichage). Fais une capture : c'est la preuve que l'interactivité tient en quelques centaines de millisecondes, une fois les données importées. Les durées des requêtes sur la VM sont celles du livrable 2 (Impala de 0,9 à 28,6 s, Hive de 108 à 209 s).

## 10. Avant de rendre la main

- [ ] Chaque page a un titre-message lisible en 5 secondes.
- [ ] Les chiffres des cartes KPI égalent les valeurs de contrôle de `controle_export.txt`.
- [ ] Aucun visuel n'affiche « (vide) » en tête : sinon, vérifie la relation ou le type de la clé.
- [ ] Les segments sont au même endroit sur chaque page.
- [ ] Les signets basculent sans réinitialiser l'année.
- [ ] Le rôle de démonstration fonctionne avec « Afficher en tant que ».
- [ ] Le fichier est enregistré, et une copie est faite sur une clé USB (plan B de la soutenance).

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| « Expression.Error : la colonne … est introuvable » | En-tête différent dans un `.tsv` | Ouvre le fichier dans le Bloc-notes, compare la première ligne au bloc M |
| Les codes « 01 » deviennent 1 | Type détecté automatiquement | Supprime l'étape « Type modifié » ajoutée par Power Query |
| Scores de satisfaction multipliés par 10 ou en erreur | Décimale à point lue en français | Garde la culture `"en-US"` dans `Table.TransformColumnTypes` |
| Un taux affiche toujours 100 % | La colonne de tri reste filtrée | Retire le filtre de toute la table (`REMOVEFILTERS ( dim_tranche_age )`), comme dans `mesures.dax` |
| La comparaison N-1 est vide | dim_temps pas marquée comme table de dates | Partie 3.2 |
| Une région est placée hors de France | Géocodage ambigu | Ajoute la colonne `pays` dans l'emplacement, ou passe au plan B |

Sources :

- Microsoft Learn, [paramètres de champs](https://learn.microsoft.com/power-bi/create-reports/power-bi-field-parameters)
- Microsoft Learn, [tables de dates dans Power BI Desktop](https://learn.microsoft.com/power-bi/transform-model/desktop-date-tables)
- Microsoft Learn, [sécurité au niveau des lignes](https://learn.microsoft.com/power-bi/enterprise/service-admin-rls)
- Microsoft Learn, [couche de carte remplie du visuel Azure Maps](https://learn.microsoft.com/azure/azure-maps/power-bi-visual-filled-map)
- Microsoft Learn, [carte de formes](https://learn.microsoft.com/power-bi/visuals/desktop-shape-map)
- Carte des régions : `regions_france.topojson`, tirée du projet france-geojson de Grégoire David (contours IGN, Licence Ouverte), convertie en TopoJSON

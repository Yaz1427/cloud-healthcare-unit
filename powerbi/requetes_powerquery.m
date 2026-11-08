// =====================================================================
// requetes_powerquery.m : requêtes Power Query du tableau de bord CHU
//
// Chaque bloc est une requête : Accueil > Transformer les données, puis
// Nouvelle source > Requête vide, Éditeur avancé, coller le bloc, et
// renommer la requête avec le nom indiqué en tête du bloc.
//
// Toutes les données sont dans un seul dossier (paramètre DossierDonnees) :
// les fichiers .tsv exportés de la VM par restitution/04_export_powerbi.sh
// et les fichiers de référence ref_departement.csv, ref_region.csv et
// population_region_2019.csv.
//
// Les types sont fixés à la main : la détection automatique ferait
// perdre le zéro des codes (« 01 » deviendrait 1) et lirait mal les
// décimales à point avec un Power BI en français (culture "en-US").
// =====================================================================


// ---------------------------------------------------------------------
// Paramètre DossierDonnees
// Accueil > Gérer les paramètres > Nouveau paramètre : nom DossierDonnees,
// type Texte, valeur actuelle = chemin du dossier, sans « \ » final,
// par exemple C:\chu\donnees_powerbi
// ---------------------------------------------------------------------


// ---------------------------------------------------------------------
// Requête LireExport (une fonction : lit un fichier .tsv de la VM)
// Clic droit > désactiver « Activer le chargement »
// ---------------------------------------------------------------------
(nom as text) as table =>
let
    Source = Csv.Document(
        File.Contents(DossierDonnees & "\" & nom & ".tsv"),
        [Delimiter = "#(tab)", Encoding = 65001, QuoteStyle = QuoteStyle.None]
    ),
    Entetes = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    // impala-shell écrit NULL en toutes lettres
    SansNull = Table.ReplaceValue(Entetes, "NULL", null, Replacer.ReplaceValue, Table.ColumnNames(Entetes))
in
    SansNull


// ---------------------------------------------------------------------
// Requête cog_departement (départements et régions du COG)
// Clic droit > désactiver « Activer le chargement » : elle sert aux fusions
// ---------------------------------------------------------------------
let
    Lire = (fichier as text) as table =>
        Table.PromoteHeaders(
            Csv.Document(
                File.Contents(DossierDonnees & "\" & fichier),
                [Delimiter = ";", Encoding = 65001, QuoteStyle = QuoteStyle.None]
            ),
            [PromoteAllScalars = true]
        ),
    Dep = Lire("ref_departement.csv"),
    Reg = Lire("ref_region.csv"),
    Jointure = Table.NestedJoin(Dep, {"code_region"}, Reg, {"code_region"}, "r", JoinKind.LeftOuter),
    Resultat = Table.ExpandTableColumn(Jointure, "r", {"nom_region"}, {"nom_region"}),
    Types = Table.TransformColumnTypes(Resultat, {
        {"code_departement", type text}, {"code_region", type text},
        {"nom_departement", type text}, {"nom_region", type text}})
in
    Types


// ---------------------------------------------------------------------
// Requête dim_temps
// Après le chargement : Outils de table > Marquer comme table de dates,
// colonne date_complete ; trier libelle_mois par mois
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_temps"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_temps", Int64.Type}, {"date_complete", type date}, {"jour", Int64.Type},
        {"mois", Int64.Type}, {"libelle_mois", type text}, {"trimestre", Int64.Type},
        {"annee", Int64.Type}, {"jour_semaine", type text}}, "en-US")
in
    Types


// ---------------------------------------------------------------------
// Requête dim_patient : région de domicile ajoutée par le COG
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_patient"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_patient", Int64.Type}, {"sexe", type text},
        {"annee_naissance", Int64.Type}, {"code_departement", type text}}, "en-US"),
    Jointure = Table.NestedJoin(Types, {"code_departement"}, cog_departement, {"code_departement"}, "cog", JoinKind.LeftOuter),
    Geo = Table.ExpandTableColumn(Jointure, "cog", {"nom_departement", "nom_region"},
        {"nom_departement_patient", "nom_region_patient"}),
    Inconnue = Table.ReplaceValue(Geo, null, "Inconnue", Replacer.ReplaceValue,
        {"nom_departement_patient", "nom_region_patient"}),
    AvecPays = Table.AddColumn(Inconnue, "pays", each "France", type text)
in
    AvecPays


// ---------------------------------------------------------------------
// Requête dim_professionnel
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_professionnel"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_professionnel", Int64.Type}, {"identifiant_source", type text},
        {"profession", type text}, {"specialite", type text}, {"categorie", type text}})
in
    Types


// ---------------------------------------------------------------------
// Requête dim_diagnostic
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_diagnostic"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_diagnostic", Int64.Type}, {"code_diagnostic", type text},
        {"libelle_diagnostic", type text}}),
    // Chapitre de la classification : première lettre du code (A00 à Z99)
    Chapitre = Table.AddColumn(Types, "lettre_code", each Text.Start([code_diagnostic], 1), type text)
in
    Chapitre


// ---------------------------------------------------------------------
// Requête dim_etablissement
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_etablissement"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_etablissement", Int64.Type}, {"finess", type text}, {"raison_sociale", type text},
        {"commune", type text}, {"code_departement", type text},
        {"code_region", type text}, {"nom_region", type text}}),
    AvecPays = Table.AddColumn(Types, "pays", each "France", type text)
in
    AvecPays


// ---------------------------------------------------------------------
// Requête dim_region : population 2019 ajoutée (INSEE, populations légales)
// ---------------------------------------------------------------------
let
    Source = LireExport("dim_region"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_region", Int64.Type}, {"code_region", type text}, {"nom_region", type text}}),
    Pop = Table.TransformColumnTypes(
        Table.PromoteHeaders(
            Csv.Document(
                File.Contents(DossierDonnees & "\population_region_2019.csv"),
                [Delimiter = ";", Encoding = 65001, QuoteStyle = QuoteStyle.None]
            ),
            [PromoteAllScalars = true]
        ),
        {{"code_region", type text}, {"population_2019", Int64.Type}}),
    Jointure = Table.NestedJoin(Types, {"code_region"}, Pop, {"code_region"}, "p", JoinKind.LeftOuter),
    Resultat = Table.ExpandTableColumn(Jointure, "p", {"population_2019"}, {"population_2019"}),
    AvecPays = Table.AddColumn(Resultat, "pays", each "France", type text)
in
    AvecPays


// ---------------------------------------------------------------------
// Requête fait_consultation
// ---------------------------------------------------------------------
let
    Source = LireExport("fait_consultation"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_temps", Int64.Type}, {"id_patient", Int64.Type}, {"id_professionnel", Int64.Type},
        {"id_diagnostic", Int64.Type}, {"id_etablissement", Int64.Type},
        {"age_patient", Int64.Type}, {"nb_consultation", Int64.Type}, {"annee", Int64.Type}}, "en-US")
in
    Types


// ---------------------------------------------------------------------
// Requête fait_hospitalisation
// ---------------------------------------------------------------------
let
    Source = LireExport("fait_hospitalisation"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_temps", Int64.Type}, {"id_patient", Int64.Type}, {"id_diagnostic", Int64.Type},
        {"id_etablissement", Int64.Type}, {"age_patient", Int64.Type},
        {"duree_sejour", Int64.Type}, {"nb_hospitalisation", Int64.Type}, {"annee", Int64.Type}}, "en-US")
in
    Types


// ---------------------------------------------------------------------
// Requête fait_deces (agrégé par mois, région, sexe et âge à l'export)
// ---------------------------------------------------------------------
let
    Source = LireExport("fait_deces"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_temps", Int64.Type}, {"id_region", Int64.Type}, {"sexe", type text},
        {"age_deces", Int64.Type}, {"nb_deces", Int64.Type}, {"annee", Int64.Type}}, "en-US")
in
    Types


// ---------------------------------------------------------------------
// Requête fait_satisfaction
// ---------------------------------------------------------------------
let
    Source = LireExport("fait_satisfaction"),
    Types = Table.TransformColumnTypes(Source, {
        {"id_temps", Int64.Type}, {"id_etablissement", Int64.Type},
        {"score_global", type number}, {"nb_repondants", Int64.Type}, {"annee", Int64.Type}}, "en-US")
in
    Types


// ---------------------------------------------------------------------
// Requête Actualisation (date affichée sur la synthèse)
// ---------------------------------------------------------------------
let
    Source = #table(type table [#"Actualisé le" = datetime], {{DateTime.LocalNow()}})
in
    Source

"""Synthèse et graphique du benchmark avant/après.

Lit le CSV écrit par bench/run_bench.sh, calcule la médiane des durées de
chaque requête pour chaque configuration, puis écrit à côté du CSV :
    synthese_<horodatage>.csv    médianes, gains et respect du seuil de 2 min
    avant_apres_<horodatage>.png barres groupées par requête, seuil de 2 min
La synthèse est aussi affichée en Markdown, prête pour le rapport.

À lancer sur le PC (Python 3 et matplotlib), pas dans la VM :
    python bench/graphiques.py resultats/benchmark/mesures_<horodatage>.csv
    python bench/graphiques.py resultats/benchmark/mesures_<horodatage>.csv --log
"""

import argparse
import csv
import statistics
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

SEUIL_S = 120

# Ordre et couleurs fixes : une couleur suit sa configuration, jamais son
# rang. Palette catégorielle validée pour les daltonismes (paires voisines).
CONFIGURATIONS = [
    ("avant", "Avant : texte brut (Hive)", "#2a78d6"),
    ("partitions", "Partitions seules (Hive)", "#eb6834"),
    ("apres_hive", "Après optimisation (Hive)", "#1baf7a"),
    ("apres_impala", "Après optimisation (Impala)", "#eda100"),
]

ORDRE_REQUETES = [
    "kpi1", "kpi2", "kpi2_agregat", "kpi3", "kpi4", "kpi5",
    "kpi5_agregat", "kpi6", "kpi7", "kpi8", "q9",
]

ENCRE = "#0b0b0b"
ENCRE_SECONDAIRE = "#52514e"
GRILLE = "#e1e0d9"
AXE = "#c3c2b7"
SEUIL_COULEUR = "#d03b3b"


def libelle(requete):
    """Nom lisible d'une requête, par exemple kpi2_agregat -> KPI 2 (agrégat)."""
    base, _, variante = requete.partition("_")
    nom = base.upper().replace("KPI", "KPI ") if base.startswith("kpi") else base.upper()
    return f"{nom}\n(agrégat)" if variante == "agregat" else nom


def lire_mesures(chemin):
    """Durées valides par (requête, configuration)."""
    durees = defaultdict(list)
    with open(chemin, newline="", encoding="utf-8") as f:
        for ligne in csv.DictReader(f, delimiter=";"):
            if ligne["statut"] != "ok" or not ligne["duree_s"]:
                continue
            durees[(ligne["requete"], ligne["configuration"])].append(float(ligne["duree_s"]))
    return durees


def calculer_synthese(durees):
    """Médiane par requête et configuration, dans un ordre stable."""
    requetes_vues = {r for r, _ in durees}
    requetes = [r for r in ORDRE_REQUETES if r in requetes_vues]
    requetes += sorted(requetes_vues - set(ORDRE_REQUETES))
    configs = [c for c, _, _ in CONFIGURATIONS if any(c == k for _, k in durees)]
    medianes = {
        (r, c): statistics.median(v) for (r, c), v in durees.items()
    }
    return requetes, configs, medianes


def ecrire_synthese(chemin, requetes, configs, medianes):
    colonnes = ["requete"] + [f"mediane_{c}_s" for c in configs]
    if "avant" in configs:
        colonnes += [f"gain_{c}" for c in configs if c != "avant"]
    colonnes += [f"sous_2_min_{c}" for c in configs]
    with open(chemin, "w", newline="", encoding="utf-8") as f:
        ecrivain = csv.writer(f, delimiter=";")
        ecrivain.writerow(colonnes)
        for r in requetes:
            ligne = [r]
            ligne += [f"{medianes[(r, c)]:.2f}" if (r, c) in medianes else "" for c in configs]
            if "avant" in configs:
                for c in configs:
                    if c == "avant":
                        continue
                    if (r, "avant") in medianes and (r, c) in medianes and medianes[(r, c)] > 0:
                        ligne.append(f"{medianes[(r, 'avant')] / medianes[(r, c)]:.1f}")
                    else:
                        ligne.append("")
            ligne += [
                ("oui" if medianes[(r, c)] <= SEUIL_S else "non") if (r, c) in medianes else ""
                for c in configs
            ]
            ecrivain.writerow(ligne)


def afficher_markdown(requetes, configs, medianes):
    noms = {c: n for c, n, _ in CONFIGURATIONS}
    print("| Requête | " + " | ".join(noms[c] for c in configs) + " |")
    print("|---|" + "---|" * len(configs))
    for r in requetes:
        cellules = [
            f"{medianes[(r, c)]:.1f} s" if (r, c) in medianes else "non mesurée"
            for c in configs
        ]
        print(f"| {libelle(r).replace(chr(10), ' ')} | " + " | ".join(cellules) + " |")


def tracer(chemin, requetes, configs, medianes, echelle_log, une_seule=False):
    couleurs = {c: coul for c, _, coul in CONFIGURATIONS}
    noms = {c: n for c, n, _ in CONFIGURATIONS}
    largeur = 0.8 / len(configs)

    fig, ax = plt.subplots(figsize=(11, 5.5), dpi=200)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")

    for i, c in enumerate(configs):
        positions, valeurs = [], []
        for j, r in enumerate(requetes):
            if (r, c) in medianes:
                positions.append(j - 0.4 + largeur * (i + 0.5))
                valeurs.append(medianes[(r, c)])
        ax.bar(positions, valeurs, width=largeur, color=couleurs[c], label=noms[c],
               edgecolor="white", linewidth=1.5, zorder=3)

    ax.axhline(SEUIL_S, color=SEUIL_COULEUR, linestyle="--", linewidth=1.5, zorder=4,
               label="Seuil de 2 minutes")

    if echelle_log:
        ax.set_yscale("log")
        ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}"))
    ax.set_xticks(range(len(requetes)))
    ax.set_xticklabels([libelle(r) for r in requetes], color=ENCRE_SECONDAIRE, fontsize=9)
    ax.tick_params(axis="y", colors=ENCRE_SECONDAIRE, labelsize=9)
    ax.tick_params(axis="both", length=0)
    # Avec une seule exécution par requête, il n'y a pas de médiane à annoncer
    mesure = "Durée" if une_seule else "Durée médiane"
    titre = ("Temps de réponse par requête (une exécution), avant et après optimisation"
             if une_seule else "Temps de réponse médian par requête, avant et après optimisation")
    ax.set_ylabel(mesure + " (secondes)" + (", échelle log" if echelle_log else ""),
                  color=ENCRE_SECONDAIRE, fontsize=10)
    ax.set_title(titre, color=ENCRE, fontsize=12, loc="left", pad=44)
    ax.grid(axis="y", color=GRILLE, linewidth=0.8, zorder=0)
    for cote in ("top", "right", "left"):
        ax.spines[cote].set_visible(False)
    ax.spines["bottom"].set_color(AXE)
    # Les configurations dans leur ordre fixe, le seuil en dernier
    poignees, etiquettes = ax.get_legend_handles_labels()
    ordre = sorted(range(len(etiquettes)), key=lambda k: etiquettes[k] == "Seuil de 2 minutes")
    ax.legend([poignees[k] for k in ordre], [etiquettes[k] for k in ordre],
              loc="lower left", bbox_to_anchor=(0, 1.0), ncol=3, frameon=False,
              fontsize=9, labelcolor=ENCRE_SECONDAIRE, handlelength=1.6, borderaxespad=0.2)

    fig.tight_layout()
    fig.savefig(chemin, facecolor="white")
    plt.close(fig)


def main():
    parseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parseur.add_argument("mesures", type=Path, help="CSV écrit par bench/run_bench.sh")
    parseur.add_argument("--log", action="store_true", help="axe des durées en échelle log")
    args = parseur.parse_args()

    durees = lire_mesures(args.mesures)
    if not durees:
        raise SystemExit("Aucune mesure valide (statut ok) dans le fichier.")
    requetes, configs, medianes = calculer_synthese(durees)

    suffixe = args.mesures.stem.replace("mesures_", "", 1)
    synthese = args.mesures.with_name(f"synthese_{suffixe}.csv")
    graphique = args.mesures.with_name(f"avant_apres_{suffixe}.png")
    ecrire_synthese(synthese, requetes, configs, medianes)
    une_seule = all(len(v) == 1 for v in durees.values())
    tracer(graphique, requetes, configs, medianes, args.log, une_seule)

    afficher_markdown(requetes, configs, medianes)
    print(f"\nSynthèse : {synthese}\nGraphique : {graphique}")


if __name__ == "__main__":
    main()

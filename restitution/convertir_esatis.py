"""convertir_esatis.py : e-Satis 48 h MCO (fichier Excel de la HAS) vers les deux CSV du lot S3

Rôle    : écrire, sans en-tête et avec le séparateur « ; » de la Silver,
          - satisfaction.csv          : finess;annee_recueil;score_global;nb_repondants;date_chargement
          - esatis_etablissements.csv : finess;raison_sociale;commune;code_commune_insee;code_departement;date_chargement
Règles  : R5, le FINESS géographique sur 9 caractères, à défaut le FINESS juridique ;
          score global ajusté (échelle 0 à 100) ; seuls les établissements notés sont gardés ;
          R6, le département vient des premiers caractères du FINESS (97x pour les DOM).
Machine : un poste avec Python 3, pandas et openpyxl (pas la VM)

Lancement :
  python3 restitution/convertir_esatis.py resultats-esatis48h-mco-open-data-2020.xlsx 2020 sortie/
"""
import re
import sys
from datetime import date
from pathlib import Path

import pandas as pd


def finess_valide(v):
    v = str(v).strip().upper() if isinstance(v, str) else ''
    if re.fullmatch(r'\d{8}', v):
        v = '0' + v
    return v if re.fullmatch(r'(\d{2}|2A|2B)[0-9A-Z]{7}', v) else None


def departement(f):
    if f.startswith('97'):
        return '97' + f[3]
    if f.startswith('98'):
        return '976'
    return f[:2]


def main(xlsx, annee, sortie):
    sortie = Path(sortie)
    sortie.mkdir(parents=True, exist_ok=True)
    jour = date.today().isoformat()
    df = pd.read_excel(xlsx, dtype=str)
    df['f'] = df['finess_geo'].map(finess_valide)
    df['f'] = df['f'].fillna(df['finess'].map(finess_valide))
    df['score'] = pd.to_numeric(df['score_all_rea_ajust'], errors='coerce')
    df['nb'] = pd.to_numeric(df['nb_rep_score_all_rea_ajust'], errors='coerce')
    print(f'Lignes du fichier : {len(df)}')
    print(f'FINESS invalides  : {df["f"].isna().sum()}')
    notes = df[df['f'].notna() & df['score'].notna()].copy()
    assert not notes['f'].duplicated().any(), 'FINESS en double'
    notes['dep'] = notes['f'].map(departement)
    notes['rs'] = (notes['rs_finess_geo'].fillna(notes['rs_finess']).fillna('')
                   .str.replace(r'[;\r\n]+', ' ', regex=True).str.strip())
    print(f'Établissements notés : {len(notes)} (non notés écartés : {len(df) - len(notes)})')
    print(f'Score global : {notes["score"].min():.2f} à {notes["score"].max():.2f}, '
          f'moyenne {notes["score"].mean():.2f}')
    with open(sortie / 'satisfaction.csv', 'w', encoding='utf-8', newline='\n') as out:
        for r in notes.itertuples():
            nb = '' if pd.isna(r.nb) else str(int(r.nb))
            out.write(f'{r.f};{annee};{r.score:.2f};{nb};{jour}\n')
    with open(sortie / 'esatis_etablissements.csv', 'w', encoding='utf-8', newline='\n') as out:
        for r in notes.itertuples():
            out.write(f'{r.f};{r.rs};;;{r.dep};{jour}\n')
    print(f'Écrit : {sortie / "satisfaction.csv"} et {sortie / "esatis_etablissements.csv"}')
    return notes


if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), sys.argv[3])

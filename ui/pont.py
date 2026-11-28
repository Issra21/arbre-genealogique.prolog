"""Pont Python <-> Prolog : appelle `swipl cli.pl` et décode le JSON.

Respecte le contrat décrit dans docs/contrat_json.md :
    swipl cli.pl -- <fichier_faits> <commande> [arguments]
La réponse est un objet JSON UTF-8 sur la sortie standard ; en cas d'erreur
{"erreur": "..."} et code de sortie 1.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

def _trouver_racine() -> Path:
    """Dossier contenant cli.pl : à côté de ui/, ou un cran plus haut (si ui/ est dans un sous-dossier)."""
    ici = Path(__file__).resolve().parent
    for candidat in (ici.parent, ici.parent.parent, ici.parent.parent.parent):
        if (candidat / "cli.pl").exists():
            return candidat
    return ici.parent


RACINE = _trouver_racine()                           # dossier contenant cli.pl
CLI = RACINE / "cli.pl"
DONNEES = RACINE / "donnees"

# Emplacements habituels de swipl sous Windows si le PATH n'est pas réglé
_CHEMINS_WINDOWS = [
    r"C:\Program Files\swipl\bin\swipl.exe",
    r"C:\Program Files (x86)\swipl\bin\swipl.exe",
]


class ErreurProlog(RuntimeError):
    """Erreur renvoyée par cli.pl ou impossibilité de lancer swipl."""


def trouver_swipl() -> str | None:
    chemin = shutil.which("swipl")
    if chemin:
        return chemin
    for c in _CHEMINS_WINDOWS:
        if os.path.exists(c):
            return c
    return None


def version_swipl() -> str | None:
    swipl = trouver_swipl()
    if not swipl:
        return None
    try:
        r = subprocess.run([swipl, "--version"], capture_output=True, text=True, timeout=15)
        return r.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def appeler(fichier, *args) -> dict:
    """Exécute une commande de cli.pl sur `fichier` et renvoie le dict JSON."""
    swipl = trouver_swipl()
    if not swipl:
        raise ErreurProlog(
            "SWI-Prolog est introuvable. Installez-le (https://www.swi-prolog.org/download/stable) "
            "en cochant « Add swipl to the system PATH », puis relancez l'application."
        )
    if not CLI.exists():
        raise ErreurProlog(
            f"cli.pl est introuvable ({CLI}). Le dossier ui/ doit se trouver dans le dépôt de la partie A, "
            "à côté de cli.pl (ou dans un sous-dossier direct de celui-ci)."
        )
    if not Path(fichier).exists():
        raise ErreurProlog(f"Fichier de faits introuvable : {fichier}")
    cmd = [swipl, str(CLI), "--", Path(fichier).as_posix(), *map(str, args)]
    options = {}
    if sys.platform == "win32":                       # pas de fenêtre console qui clignote
        options["creationflags"] = subprocess.CREATE_NO_WINDOW
    try:
        # stdin fermé : swipl ne peut jamais attendre une saisie (invite interactive)
        r = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace",
                           stdin=subprocess.DEVNULL, cwd=str(RACINE), timeout=60, **options)
    except subprocess.TimeoutExpired as e:
        raise ErreurProlog("swipl ne répond pas (délai dépassé)") from e
    sortie = (r.stdout or "").strip()
    if not sortie:
        raise ErreurProlog((r.stderr or "swipl n'a rien renvoyé").strip()[:400])
    try:
        donnees = json.loads(sortie.splitlines()[-1])
    except json.JSONDecodeError as e:
        raise ErreurProlog(f"Réponse illisible de swipl : {sortie[:200]}") from e
    if isinstance(donnees, dict) and "erreur" in donnees:
        raise ErreurProlog(str(donnees["erreur"]))
    return donnees


# --------------------------------------------------------------------------
#  Faits ajoutés depuis l'interface : on les ajoute à une copie du fichier
#  de faits (le fichier d'origine n'est jamais modifié).
# --------------------------------------------------------------------------
def identifiant_depuis_nom(nom: str) -> str:
    """« Élie Ben Ali » -> « elie_ben_ali » (atome Prolog valide)."""
    s = unicodedata.normalize("NFKD", nom).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")
    return s if s and s[0].isalpha() else f"p_{s}" if s else ""


def fait_personne(ident: str, nom: str, sexe: str, naissance: int, deces) -> str:
    d = "vivant" if deces in (None, "", "vivant") else int(deces)
    nom_q = nom.replace("\\", "\\\\").replace("'", "\\'")
    return f"personne({ident}, '{nom_q}', {sexe}, {int(naissance)}, {d})."


def fait_parent(parent: str, enfant: str) -> str:
    return f"parent({parent}, {enfant})."


def fait_conjoint(a: str, b: str) -> str:
    return f"conjoint({a}, {b})."


def fichier_avec_ajouts(base: Path, ajouts: list[str]) -> Path:
    """Renvoie `base` tel quel, ou une copie temporaire = base + faits ajoutés."""
    if not ajouts:
        return Path(base)
    texte = Path(base).read_text(encoding="utf-8") + "\n% --- faits ajoutés depuis l'interface ---\n" \
        + "\n".join(ajouts) + "\n"
    h = hashlib.sha1(texte.encode("utf-8")).hexdigest()[:12]
    dossier = Path(tempfile.gettempdir()) / "arbre_genealogique_ui"
    dossier.mkdir(exist_ok=True)
    cible = dossier / f"faits_{h}.pl"
    if not cible.exists():
        cible.write_text(texte, encoding="utf-8")
    return cible

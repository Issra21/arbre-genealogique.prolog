"""Tests rapides de l'interface (sans pytest) :   python tests/test_ui.py

Vérifie le pont Python-Prolog, le graphe et que l'application Streamlit démarre sans exception.
"""
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "ui"))
import graphe  # noqa: E402
import pont    # noqa: E402

famille = pont.DONNEES / "famille.pl"
erreurs = pont.DONNEES / "famille_erreurs.pl"

# 1. pont : commandes du contrat
g = pont.appeler(famille, "graphe")
assert g["stats"]["nb_personnes"] == len(g["personnes"]) > 0, "graphe vide"
assert g["stats"]["nb_alertes"] == 0, "la famille de test doit être cohérente"
rel = pont.appeler(famille, "relation", "nadia", "sami")
assert "tante paternelle" in rel["phrase_fr"], rel["phrase_fr"]
assert rel["explication"]["etapes"], "explication vide"
assert pont.appeler(famille, "liste", "grand_pere", "sami")["resultats"], "grand-père introuvable"
assert pont.appeler(erreurs, "alertes")["alertes"], "le jeu d'erreurs doit produire des alertes"
try:
    pont.appeler(famille, "relation", "nadia", "inconnu_xyz")
    raise SystemExit("une personne inconnue devrait lever ErreurProlog")
except pont.ErreurProlog:
    pass
print("OK pont : graphe, relation, liste, alertes, erreurs")

# 2. faits ajoutés : le fichier d'origine reste intact
avant = famille.read_text(encoding="utf-8")
f = pont.fichier_avec_ajouts(famille, [pont.fait_personne("zoe_test", "Zoé O'Neil", "f", 2000, "vivant")])
g2 = pont.appeler(f, "graphe")
assert g2["stats"]["nb_personnes"] == g["stats"]["nb_personnes"] + 1
assert famille.read_text(encoding="utf-8") == avant, "le fichier d'origine a été modifié !"
assert pont.identifiant_depuis_nom("Élie Ben Ali") == "elie_ben_ali"
print("OK ajouts : copie temporaire, fichier d'origine intact")

# 3. graphe HTML : autonome (aucune ressource externe) et sur les deux jeux de données
for fichier in (famille, erreurs):
    html = graphe.construire_html(pont.appeler(fichier, "graphe"))
    assert not re.findall(r'(?:src|href)="https?://', html), "ressource externe dans le graphe"
print("OK graphe : HTML autonome")

# 4. l'application démarre sans exception
from streamlit.testing.v1 import AppTest  # noqa: E402
at = AppTest.from_file(str(RACINE / "ui" / "app.py"), default_timeout=90).run()
assert not at.exception, [x.value for x in at.exception]
at.sidebar.selectbox[0].set_value("Famille avec erreurs (démo des alertes)").run()
assert not at.exception, [x.value for x in at.exception]
print("OK application : démarre sur les deux bases")
print("\nTous les tests de l'interface passent.")

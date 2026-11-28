"""Interface Streamlit – arbre généalogique (partie B).

Lancer depuis la racine du dépôt :   streamlit run ui/app.py
Elle ne parle à Prolog que par ui/pont.py, selon le contrat docs/contrat_json.md.
"""
from __future__ import annotations

import html
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import streamlit as st

sys.path.insert(0, str(Path(__file__).resolve().parent))
import graphe as gr   # noqa: E402
import pont           # noqa: E402

st.set_page_config(page_title="Arbre généalogique intelligent", page_icon="🌳", layout="wide")

try:
    st.markdown(f"<style>{(Path(__file__).parent / 'style.css').read_text(encoding='utf-8')}</style>",
                unsafe_allow_html=True)
except OSError:
    pass

JEUX = {
    "Famille de test (données cohérentes)": pont.DONNEES / "famille.pl",
    "Famille avec erreurs (démo des alertes)": pont.DONNEES / "famille_erreurs.pl",
}

TITRES_ALERTES = {
    "cycle": "Cycle dans la filiation",
    "parent_plus_jeune": "Parent plus jeune que son enfant",
    "parent_trop_jeune": "Parent trop jeune à la naissance",
    "trop_de_parents": "Plus de deux parents",
    "sexe_contradictoire": "Sexe contradictoire",
    "deces_avant_naissance": "Décès avant la naissance",
    "naissance_apres_deces_mere": "Naissance après le décès de la mère",
    "naissance_apres_deces_pere": "Naissance bien après le décès du père",
    "longevite_impossible": "Durée de vie impossible",
    "mariage_ascendant": "Mariage avec un ascendant",
    "mariage_fratrie": "Mariage entre frère et sœur",
    "reference_inconnue": "Personne citée mais non déclarée",
}

GROUPES = [
    ("Parents", ["pere", "mere"]), ("Frères et sœurs", ["frere_ou_soeur"]), ("Conjoint(e)", ["marie"]),
    ("Enfants", ["enfant"]), ("Grands-parents", ["grand_pere", "grand_mere"]),
    ("Petits-enfants", ["petit_enfant"]), ("Oncles et tantes", ["oncle", "tante"]),
    ("Cousins germains", ["cousin_germain"]), ("Neveux et nièces", ["neveu_ou_niece"]),
    ("Ancêtres", ["ancetre"]), ("Descendants", ["descendant"]),
]


# ------------------------------------------------------------------ helpers
def e(x) -> str:
    return html.escape(str(x), quote=True)


def html_md(contenu: str) -> None:
    st.markdown(contenu, unsafe_allow_html=True)


def afficher_html(contenu: str, hauteur: int) -> None:
    """Affiche une page HTML dans un cadre (st.iframe ou, sinon, components.html)."""
    if hasattr(st, "iframe"):
        st.iframe(contenu, height=hauteur)
    else:                                              # anciennes versions de Streamlit
        import streamlit.components.v1 as components
        components.html(contenu, height=hauteur)


@st.cache_data(show_spinner=False, max_entries=512)
def _appel(chemin: str, signature: int, *args):
    return pont.appeler(chemin, *args)


def cli(fichier: Path, *args):
    return _appel(str(fichier), Path(fichier).stat().st_mtime_ns, *args)


@st.cache_data(show_spinner=False, max_entries=64)
def _famille(chemin: str, signature: int, personne: str):
    """Toutes les listes « <relation> de X » d'un coup (appels en parallèle)."""
    relations = sorted({r for _, rels in GROUPES for r in rels})
    with ThreadPoolExecutor(max_workers=6) as pool:
        reponses = list(pool.map(lambda r: pont.appeler(chemin, "liste", r, personne), relations))
    return {r: rep["resultats"] for r, rep in zip(relations, reponses)}


def chips(ids_ou_resultats, sexe_de: dict, noms: dict) -> str:
    if not ids_ou_resultats:
        return '<span class="vide">Aucun résultat dans la base.</span>'
    out = []
    for r in ids_ou_resultats:
        i = r["id"] if isinstance(r, dict) else r
        cl = sexe_de.get(i, "x")
        out.append(f'<span class="chip {cl if cl in ("h", "f") else "x"}">{e(noms.get(i, i))}</span>')
    return '<div class="chips">' + "".join(out) + "</div>"


def texte_cousinage(c) -> str | None:
    if not c:
        return None
    d, ec = c.get("degre"), c.get("ecart", 0)
    base = {1: "cousins germains", 2: "cousins issus de germains"}.get(d, f"cousins au {d}e degré")
    return base + (f" (décalage de {ec} génération{'s' if ec > 1 else ''})" if ec else "")


# ------------------------------------------------------------------ état
if "ajouts" not in st.session_state:
    st.session_state["ajouts"] = {}
if "message" not in st.session_state:
    st.session_state["message"] = None

# ------------------------------------------------------------------ barre latérale
with st.sidebar:
    st.markdown("### 🌳 Arbre généalogique")
    st.caption("Projet Programmation et IA · SWI-Prolog + Streamlit")
    nom_jeu = st.selectbox("Base de faits", list(JEUX), help="Fichier .pl chargé par Prolog.")
    base = JEUX[nom_jeu]
    ajouts = st.session_state["ajouts"].setdefault(nom_jeu, [])
    if ajouts:
        st.info(f"{len(ajouts)} fait(s) ajouté(s) depuis l'interface (fichier d'origine intact).")
    if pont.trouver_swipl() is None:
        st.error("SWI-Prolog introuvable. Installez-le et cochez « Add swipl to the system PATH ».", icon="⚠️")

fichier = pont.fichier_avec_ajouts(base, ajouts)

# ------------------------------------------------------------------ chargement
try:
    g = cli(fichier, "graphe")
except pont.ErreurProlog as ex:
    html_md(f'<div class="erreur-box"><b>Impossible de lire la base.</b><br>{e(ex)}</div>')
    st.stop()

personnes = g["personnes"]
def _etiquettes(ps):
    """Nom affiché ; si plusieurs personnes ont le même nom, on ajoute l'année de naissance."""
    compte = {}
    for p in ps:
        compte[p["nom"]] = compte.get(p["nom"], 0) + 1
    out = {}
    for p in ps:
        n = p["nom"]
        if compte[n] > 1:
            n = f"{n} ({p['naissance']})" if p.get("naissance") else f"{n} [{p['id']}]"
        out[p["id"]] = n
    # même nom ET même année : on ajoute l'identifiant
    vus = {}
    for i, n in out.items():
        vus.setdefault(n, []).append(i)
    for n, ids in vus.items():
        if len(ids) > 1:
            for i in ids:
                out[i] = f"{n} [{i}]"
    return out


noms = _etiquettes(personnes)
sexe_de = {p["id"]: p.get("sexe") or "x" for p in personnes}
declarees = [p for p in personnes if not p.get("inconnu")]
ids_declares = [p["id"] for p in declarees]
alertes = g.get("alertes", [])
stats = g["stats"]

html_md(
    '<div class="hero"><h1>Arbre généalogique intelligent</h1>'
    "<p>Une base de connaissances Prolog qui déduit les liens de parenté, détecte les incohérences "
    "et explique chacune de ses réponses.</p>"
    '<div class="tags"><span class="tag">Liens sur 3 niveaux</span><span class="tag">Détection d\'incohérences</span>'
    '<span class="tag">Explications « pourquoi ? »</span><span class="tag">Graphe interactif</span></div></div>'
)

nb_alertes = stats.get("nb_alertes", len(alertes))
html_md(
    '<div class="stats">'
    f'<div class="stat"><div class="v">{stats["nb_personnes"]}</div><div class="l">Personnes</div></div>'
    f'<div class="stat"><div class="v">{gr.nombre_generations(g)}</div><div class="l">Générations</div></div>'
    f'<div class="stat"><div class="v">{stats["nb_mariages"]}</div><div class="l">Mariages</div></div>'
    f'<div class="stat"><div class="v">{stats["nb_liens_parent"]}</div><div class="l">Liens parent-enfant</div></div>'
    f'<div class="stat {"ko" if nb_alertes else "ok"}"><div class="v">{nb_alertes}</div>'
    '<div class="l">Alertes de cohérence</div></div></div>'
)

onglets = st.tabs(["🌳 Arbre", "🔗 Lien de parenté", "👪 Famille d'une personne", "Cohérence", "➕ Ajouter"])

# ================================================================== 1. ARBRE
with onglets[0]:
    html_md(
        '<div class="legende">'
        '<span><i class="p" style="background:#DCE9FF;border-color:#3B6FD4"></i>Homme</span>'
        '<span><i class="p" style="background:#FFE3EE;border-color:#D6457F"></i>Femme</span>'
        '<span><i class="p" style="background:#FFE1E1;border-color:#E03131"></i>Impliqué(e) dans une alerte</span>'
        '<span><i class="p" style="background:#fff;border-color:#8A94AD"></i>Non déclaré(e)</span>'
        '<span style="color:#D6457F">━ mariage</span><span>→ filiation</span>'
        "<span>Boutons + / − : zoom · glisser : déplacer · survol : détails</span></div>"
    )
    afficher_html(gr.construire_html(g, hauteur=500), 520)
    with st.expander("Voir la liste des personnes"):
        st.dataframe(
            [{"Identifiant": p["id"], "Nom": p["nom"], "Sexe": {"h": "Homme", "f": "Femme"}.get(p.get("sexe"), "?"),
              "Naissance": str(p.get("naissance") or ""), "Décès": str(p.get("deces") or "vivant(e)"),
              "Alerte": "⚠" if p.get("en_erreur") else ""} for p in personnes],
            hide_index=True)

# ================================================================== 2. LIEN
with onglets[1]:
    st.markdown("##### Quel est le lien de parenté entre deux personnes ?")
    if len(ids_declares) < 2:
        st.info("Il faut au moins deux personnes dans la base.")
    else:
        c1, c2 = st.columns(2)
        x = c1.selectbox("Première personne (X)", ids_declares, format_func=noms.get, key="lien_x")
        y = c2.selectbox("Deuxième personne (Y)", ids_declares, index=1, format_func=noms.get, key="lien_y")
        if x == y:
            st.info("Choisissez deux personnes différentes.")
        else:
            try:
                rel = cli(fichier, "relation", x, y)
            except pont.ErreurProlog as ex:
                html_md(f'<div class="erreur-box">{e(ex)}</div>')
                rel = None
            if rel:
                puces = [f'<span class="chip info">{e(rel.get("fr", ""))}</span>'] if rel.get("fr") else []
                if rel.get("degre_civil") is not None:
                    puces.append(f'<span class="chip warn">degré civil : {e(rel["degre_civil"])}</span>')
                tc = texte_cousinage(rel.get("cousinage"))
                if tc:
                    puces.append(f'<span class="chip warn">{e(tc)}</span>')
                communs = rel.get("ancetres_communs") or []
                comm_html = ""
                if communs:
                    comm_html = ('<div class="sub" style="margin-top:12px">Ancêtres communs</div>'
                                 + chips(communs, sexe_de, noms))
                html_md(f'<div class="resultat"><div class="phrase">{e(rel.get("phrase_fr", ""))}</div>'
                        f'<div class="chips">{"".join(puces)}</div>{comm_html}</div>')

                chemin = rel.get("chemin") or []
                gauche, droite = st.columns([1, 2], gap="large")
                with gauche:
                    st.markdown("**Chemin de parenté**")
                    if chemin:
                        etapes = "".join(
                            f'<div class="etape"><div class="n">{k}</div><div class="t">'
                            f'<b>{e(noms.get(s["vers"], s["vers"]))}</b> est {e(s.get("lien_fr", "lié(e)"))} '
                            f'de <b>{e(noms.get(s["de"], s["de"]))}</b></div></div>'
                            for k, s in enumerate(chemin, 1))
                        html_md(f'<div class="card">{etapes}</div>')
                    else:
                        html_md('<div class="card vide">Pas de chemin trouvé.</div>')
                with droite:
                    noeuds = {s["de"] for s in chemin} | {s["vers"] for s in chemin}
                    tout = st.toggle("Voir tout l'arbre", value=False, key="lien_tout")
                    afficher_html(gr.construire_html(
                        g, surligne=noeuds, extremites={x, y}, chemin=chemin, hauteur=380,
                        restreindre_a=None if tout else noeuds | set(communs)), 400)
                with st.expander("💡 Pourquoi ? Le raisonnement de Prolog", expanded=True):
                    expl = rel.get("explication") or {}
                    etapes = expl.get("etapes") or []
                    if etapes:
                        html_md('<div class="card">' + "".join(
                            f'<div class="etape"><div class="n">{k}</div><div class="t">{e(t)}</div></div>'
                            for k, t in enumerate(etapes, 1)) + "</div>")
                        html_md(f'<div class="sub">Conclusion : {e(rel.get("phrase_fr", ""))}</div>')
                    else:
                        st.write(expl.get("texte") or "Aucune règle détaillée pour ce lien.")

# ================================================================== 3. FAMILLE
with onglets[2]:
    if not ids_declares:
        st.info("La base est vide.")
    else:
        p = st.selectbox("Personne", ids_declares, format_func=noms.get, key="famille_p")
        try:
            fam = _famille(str(fichier), Path(fichier).stat().st_mtime_ns, p)
        except pont.ErreurProlog as ex:
            html_md(f'<div class="erreur-box">{e(ex)}</div>')
            fam = None
        if fam:
            nom = e(noms[p])
            st.markdown("##### Les questions du sujet")
            a, b, c = st.columns(3)
            with a:
                html_md(f'<div class="card"><h4>Qui est le grand-père / la grand-mère de {nom} ?</h4>'
                        f'<div class="sub">Grand-père(s)</div>{chips(fam["grand_pere"], sexe_de, noms)}'
                        f'<div class="sub" style="margin-top:10px">Grand-mère(s)</div>'
                        f'{chips(fam["grand_mere"], sexe_de, noms)}</div>')
            with b:
                html_md(f'<div class="card"><h4>Quels sont les cousins de {nom} ?</h4>'
                        f'<div class="sub">Cousins germains</div>{chips(fam["cousin_germain"], sexe_de, noms)}</div>')
            with c:
                html_md(f'<div class="card"><h4>Quels sont les oncles et tantes de {nom} ?</h4>'
                        f'<div class="sub">Oncles</div>{chips(fam["oncle"], sexe_de, noms)}'
                        f'<div class="sub" style="margin-top:10px">Tantes</div>{chips(fam["tante"], sexe_de, noms)}</div>')
            st.caption("Le lien entre deux personnes quelconques se trouve dans l'onglet « Lien de parenté ».")

            st.markdown(f"##### Toute la famille de {noms[p]}")
            cols = st.columns(3)
            k = 0
            for titre, rels in GROUPES:
                membres = []
                for r in rels:
                    membres += fam[r]
                if not membres:
                    continue
                with cols[k % 3]:
                    html_md(f'<div class="card"><h4>{e(titre)}</h4>{chips(membres, sexe_de, noms)}</div>')
                k += 1

# ================================================================== 4. COHÉRENCE
with onglets[3]:
    st.markdown("##### Contrôles de cohérence de la base")
    if not alertes:
        html_md('<div class="ok-box">Aucune incohérence détectée : les données sont cohérentes.</div>')
    else:
        html_md(f'<div class="sub">{len(alertes)} alerte(s). Les personnes concernées sont en rouge dans l\'arbre.</div>')
        for al in alertes:
            titre = TITRES_ALERTES.get(al["code"], al["code"].replace("_", " ").capitalize())
            html_md(f'<div class="alerte"><div><div class="ti">{e(titre)}</div>'
                    f'<div class="ms">{e(al.get("message", ""))}</div>'
                    f'{chips(al.get("personnes", []), sexe_de, noms)}</div></div>')
        st.caption("Astuce : passez de la base cohérente à la base avec erreurs dans la barre latérale pour la démonstration.")

# ================================================================== 5. AJOUTER
with onglets[4]:
    st.markdown("##### Enrichir la base depuis l'interface")
    st.caption("Les faits sont ajoutés à une copie temporaire : le fichier d'origine n'est jamais modifié. "
               "Les contrôles de cohérence sont relancés immédiatement.")
    if st.session_state["message"]:
        niveau, texte = st.session_state["message"]
        (st.warning if niveau == "warn" else st.success)(texte)
        st.session_state["message"] = None

    def ajouter(fait: str, description: str):
        avant = {(a["code"], tuple(a["personnes"])) for a in alertes}
        ajouts.append(fait)
        try:
            apres = cli(pont.fichier_avec_ajouts(base, ajouts), "alertes")["alertes"]
        except pont.ErreurProlog as ex:
            ajouts.pop()
            st.session_state["message"] = ("warn", f"Ajout refusé : {ex}")
            st.rerun()
        nouvelles = [a for a in apres if (a["code"], tuple(a["personnes"])) not in avant]
        if nouvelles:
            st.session_state["message"] = (
                "warn", f"{description} — mais {len(nouvelles)} nouvelle(s) alerte(s) : "
                        + " ; ".join(a["message"] for a in nouvelles[:3])
                        + (" ; … (voir l'onglet Cohérence)" if len(nouvelles) > 3 else ""))
        else:
            st.session_state["message"] = ("ok", f"{description} — aucune incohérence créée.")
        st.rerun()

    col_a, col_b, col_c = st.columns(3, gap="large")
    with col_a:
        v = st.session_state.get("form_v", 0)          # change après chaque ajout : le formulaire repart vide
        with st.container(border=True):
            st.markdown("**Nouvelle personne**")
            nom_p = st.text_input("Nom", placeholder="Ex. Amira", key=f"p_nom_{v}")
            sexe_p = st.radio("Sexe", ["Femme", "Homme"], horizontal=True, key=f"p_sexe_{v}")
            naiss = st.number_input("Année de naissance", 1700, 2026, 1990, key=f"p_naiss_{v}")
            decede = st.checkbox("Décédé(e)", key=f"p_decede_{v}")
            annee_deces = st.number_input("Année de décès", 1700, 2026, 2020, key=f"p_deces_{v}", disabled=not decede)
            if st.button("Ajouter la personne", key=f"p_ajouter_{v}"):
                ident = pont.identifiant_depuis_nom(nom_p)
                if not ident:
                    st.error("Donnez un nom (lettres ou chiffres).")
                else:
                    base_id, n = ident, 2
                    while ident in {p["id"] for p in personnes}:      # même nom autorisé : id différent
                        ident, n = f"{base_id}_{n}", n + 1
                    st.session_state["form_v"] = v + 1
                    ajouter(pont.fait_personne(ident, nom_p.strip(), "f" if sexe_p == "Femme" else "h", naiss,
                                               annee_deces if decede else "vivant"),
                            f"{nom_p.strip()} ajouté(e)")
    with col_b:
        with st.form("f_parent", clear_on_submit=False):
            st.markdown("**Lien parent → enfant**")
            par = st.selectbox("Parent", ids_declares, format_func=noms.get, key="add_par")
            enf = st.selectbox("Enfant", ids_declares, index=min(1, max(len(ids_declares) - 1, 0)),
                               format_func=noms.get, key="add_enf")
            if st.form_submit_button("Déclarer le lien"):
                existe = any(l["type"] == "parent" and l["de"] == par and l["vers"] == enf for l in g["liens"])
                if par == enf:
                    st.error("Un parent ne peut pas être son propre enfant.")
                elif existe:
                    st.error("Ce lien existe déjà.")
                else:
                    ajouter(pont.fait_parent(par, enf), f"{noms[par]} déclaré(e) parent de {noms[enf]}")
    with col_c:
        with st.form("f_conjoint", clear_on_submit=False):
            st.markdown("**Mariage**")
            m1 = st.selectbox("Époux / épouse 1", ids_declares, format_func=noms.get, key="add_m1")
            m2 = st.selectbox("Époux / épouse 2", ids_declares, index=min(1, max(len(ids_declares) - 1, 0)),
                              format_func=noms.get, key="add_m2")
            if st.form_submit_button("Déclarer le mariage"):
                existe = any(l["type"] == "conjoint" and {l["de"], l["vers"]} == {m1, m2} for l in g["liens"])
                if m1 == m2:
                    st.error("Choisissez deux personnes différentes.")
                elif existe:
                    st.error("Ce mariage existe déjà.")
                else:
                    ajouter(pont.fait_conjoint(m1, m2), f"Mariage de {noms[m1]} et {noms[m2]} déclaré")

    if ajouts:
        st.markdown("**Faits ajoutés**")
        st.code("\n".join(ajouts), language="prolog")
        d1, d2 = st.columns([1, 1])
        d1.download_button("⬇️ Télécharger la base modifiée (.pl)", data=Path(fichier).read_bytes(),
                           file_name="famille_modifiee.pl", mime="text/plain")
        if d2.button("↩️ Annuler tous les ajouts"):
            ajouts.clear()
            st.rerun()

"""Construction du graphe interactif (pyvis / vis-network) à partir de la
réponse JSON de la commande `graphe`.

Mise en page « arbre de famille » : une rangée par génération, les couples
côte à côte et un petit point d'union d'où partent les flèches vers les enfants.
Aucune bibliothèque de mise en page externe : le calcul est fait ici.
"""
from __future__ import annotations

import re

from pyvis.network import Network

ZOOM_MIN, ZOOM_MAX = 0.5, 2.0   # zoom minimal / maximal du graphe (0.5 = 50 %)
DX, DY = 128, 120          # espacement horizontal / vertical (pixels)

COULEURS = {
    "h": ("#DCE9FF", "#3B6FD4"),      # homme : fond, bordure
    "f": ("#FFE3EE", "#D6457F"),      # femme
    "?": ("#ECEFF5", "#8A94AD"),      # inconnu
}
ROUGE = ("#FFE1E1", "#E03131")
OR = ("#FFF3BF", "#F08C00")
ORANGE_FORT = ("#FFD8A8", "#D9480F")


def _propre(texte) -> str:
    """Retire ce qui pourrait casser la page HTML du graphe."""
    return str(texte).replace("<", "").replace(">", "").replace("&", "et").replace("\"", "'")


# ---------------------------------------------------------------- niveaux
def calculer_niveaux(personnes: list[dict], liens: list[dict]) -> dict[str, int]:
    """Génération de chaque personne (0 = racines), robuste aux cycles."""
    ids = [p["id"] for p in personnes]
    parents = {i: [] for i in ids}
    for l in liens:
        if l["type"] == "parent" and l["vers"] in parents and l["de"] in parents:
            parents[l["vers"]].append(l["de"])
    niveau: dict[str, int] = {}

    def niv(p: str, pile: tuple = ()) -> int:
        if p in niveau:
            return niveau[p]
        if p in pile:                       # cycle (données erronées)
            return 0
        ps = parents[p]
        n = 0 if not ps else 1 + max(niv(q, pile + (p,)) for q in ps)
        niveau[p] = n
        return n

    for i in ids:
        niv(i)
    return niveau


def nombre_generations(graphe: dict) -> int:
    niveaux = calculer_niveaux(graphe["personnes"], graphe["liens"])
    return (max(niveaux.values()) + 1) if niveaux else 0


# ----------------------------------------------------------------- layout
def calculer_positions(personnes, liens, niveau):
    ids = [p["id"] for p in personnes]
    parents = {i: [] for i in ids}
    enfants = {i: [] for i in ids}
    conjoints = {i: [] for i in ids}
    for l in liens:
        a, b = l["de"], l["vers"]
        if a not in parents or b not in parents:
            continue
        if l["type"] == "parent":
            parents[b].append(a)
            if b not in enfants[a]:
                enfants[a].append(b)
        elif l["type"] == "conjoint":
            if b not in conjoints[a]:
                conjoints[a].append(b)
            if a not in conjoints[b]:
                conjoints[b].append(a)

    rattache: dict[str, str] = {}              # conjoint sans parents -> personne de l'arbre
    for i in ids:
        if parents[i]:
            continue
        for c in conjoints[i]:
            if c in rattache or rattache.get(c) == i:
                continue
            if parents[c] or ids.index(c) < ids.index(i):
                rattache[i] = c
                break

    racines = [i for i in ids if not parents[i] and i not in rattache]
    ordre_racine = {r: k for k, r in enumerate(racines)}

    def racine_de(p: str, garde: int = 0) -> int:
        while parents[p] and garde < 50:
            p, garde = parents[p][0], garde + 1
        return ordre_racine.get(rattache.get(p, p), 0)

    def cle_enfant(e: str) -> int:
        """Enfant marié(e) dans une autre famille : placé du côté de cette famille."""
        mien = racine_de(e)
        for c in conjoints[e]:
            if parents[c]:
                autre = racine_de(c)
                if autre < mien:
                    return -1
                if autre > mien:
                    return 1
        return 0

    vus: set[str] = set()
    pos: dict[str, tuple[float, float]] = {}

    def unite(tete: str):
        membres = [tete] + [c for c in conjoints[tete] if rattache.get(c) == tete and c not in vus]
        return membres

    def poser(tete: str, x0: float) -> float:
        """Place l'unité `tete` (+ conjoints) à partir de x0 ; renvoie sa largeur."""
        membres = unite(tete)
        vus.update(membres)
        fils, deja = [], set()
        for m in membres:
            for e in enfants[m]:
                if e not in vus and e not in deja and e not in rattache:
                    fils.append(e)
                    deja.add(e)
        fils.sort(key=cle_enfant)
        x = x0
        largeurs = []
        # largeur de la descendance
        cx = x0
        total = 0.0
        positions_fils = []
        for e in fils:
            if e in vus:
                continue
            w = poser(e, cx)
            positions_fils.append((e, cx, w))
            cx += w
            total += w
        propre = len(membres) * DX
        largeur = max(propre, total)
        debut = x0 + (largeur - propre) / 2
        for k, m in enumerate(membres):
            pos[m] = (debut + k * DX + DX / 2, niveau[tete] * DY)
        # recentre la descendance sous l'unité si elle est plus étroite
        if total < propre and positions_fils:
            decal = (propre - total) / 2
            for e, _, _ in positions_fils:
                _decaler(e, decal)
        return largeur

    def _decaler(p: str, d: float):
        stack = [p]
        vu_local = set()
        while stack:
            q = stack.pop()
            if q in vu_local or q not in pos:
                continue
            vu_local.add(q)
            pos[q] = (pos[q][0] + d, pos[q][1])
            for m in conjoints[q]:
                if rattache.get(m) == q:
                    stack.append(m)
            for e in enfants[q]:
                if e in pos and e not in rattache:
                    stack.append(e)

    x = 0.0
    for r in racines:
        if r not in vus:
            x += poser(r, x)
    # personnes non atteintes (cycles, données erronées) : rangée à part
    for i in ids:
        if i not in pos:
            pos[i] = (x + DX / 2, niveau.get(i, 0) * DY)
            x += DX
    return pos, parents, conjoints


# ------------------------------------------------------------------ rendu
OPTIONS = """
{
  "layout": {"hierarchical": {"enabled": false}},
  "physics": {"enabled": false},
  "interaction": {"hover": true, "tooltipDelay": 120, "zoomView": false, "dragView": true,
                   "navigationButtons": false, "keyboard": false},
  "nodes": {"shape": "box", "margin": 10, "borderWidth": 2,
            "shadow": {"enabled": true, "size": 8, "x": 0, "y": 3, "color": "rgba(40,60,120,0.18)"},
            "font": {"face": "Segoe UI, Helvetica, Arial, sans-serif", "size": 15, "color": "#1F2A44"},
            "shapeProperties": {"borderRadius": 10}},
  "edges": {"smooth": false, "selectionWidth": 1}
}
"""


_SCRIPT_ZOOM = """<style>
#zoombar { position:fixed; top:12px; right:12px; z-index:50; display:flex; flex-direction:column; gap:6px; }
#zoombar button { width:36px; height:36px; border:1px solid #D5DDF5; border-radius:10px; background:#fff; color:#2B3F9E;
                  font:700 20px "Segoe UI",Arial,sans-serif; line-height:1; cursor:pointer; padding:0;
                  box-shadow:0 2px 8px rgba(40,60,120,.14); }
#zoombar button:hover { background:#E8EEFF; }
#zoombar svg { width:16px; height:16px; stroke:#2B3F9E; fill:none; stroke-width:2.2; stroke-linecap:round; stroke-linejoin:round; }
</style>
<div id="zoombar">
  <button id="zp" title="Zoom avant" aria-label="Zoom avant">+</button>
  <button id="zm" title="Zoom arrière" aria-label="Zoom arrière">&minus;</button>
  <button id="zf" title="Ajuster à la fenêtre" aria-label="Ajuster à la fenêtre">
    <svg viewBox="0 0 16 16"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></button>
</div>
<script>
(function () {
  var MIN = __MIN__, MAX = __MAX__;
  function zoomer(facteur) {
    var n = Math.min(MAX, Math.max(MIN, network.getScale() * facteur));
    network.moveTo({scale: n, animation: {duration: 180, easingFunction: "easeInOutQuad"}});
  }
  function ajuster(anime) {
    network.fit({minZoomLevel: MIN, maxZoomLevel: 1.2, animation: anime ? {duration: 220} : false});
  }
  document.getElementById("zp").onclick = function () { zoomer(1.25); };
  document.getElementById("zm").onclick = function () { zoomer(0.8); };
  document.getElementById("zf").onclick = function () { ajuster(true); };
  network.once("afterDrawing", function () { ajuster(false); });
})();
</script>
"""


def construire_html(graphe: dict, surligne: set[str] | None = None, extremites: set[str] | None = None,
                    chemin: list[dict] | None = None, hauteur: int = 600,
                    restreindre_a: set[str] | None = None) -> str:
    surligne = set(surligne or [])
    extremites = set(extremites or [])
    personnes, liens = graphe["personnes"], graphe["liens"]
    if restreindre_a is not None:                   # sous-arbre : personnes choisies + leurs conjoints
        garde = set(restreindre_a)
        for l in liens:
            if l["type"] == "conjoint" and (l["de"] in restreindre_a or l["vers"] in restreindre_a):
                garde.update((l["de"], l["vers"]))
        personnes = [p for p in personnes if p["id"] in garde]
        liens = [l for l in liens if l["de"] in garde and l["vers"] in garde]
    niveau = calculer_niveaux(personnes, liens)
    pos, parents, conjoints = calculer_positions(personnes, liens, niveau)

    paires_chemin = set()
    for s in chemin or []:
        paires_chemin.add((s["de"], s["vers"]))
        paires_chemin.add((s["vers"], s["de"]))

    net = Network(height=f"{hauteur}px", width="100%", directed=True, bgcolor="#FFFFFF",
                  cdn_resources="in_line")
    net.set_options(OPTIONS)

    for p in personnes:
        i = p["id"]
        fond, bord = COULEURS.get(p.get("sexe") or "?", COULEURS["?"])
        largeur_bord = 2
        if p.get("inconnu"):
            fond, bord = "#FFFFFF", "#8A94AD"
        if p.get("en_erreur"):
            fond, bord, largeur_bord = ROUGE[0], ROUGE[1], 3
        if i in surligne:
            fond, bord, largeur_bord = OR[0], OR[1], 3
        if i in extremites:
            fond, bord, largeur_bord = ORANGE_FORT[0], ORANGE_FORT[1], 4
        nom = _propre(p.get("nom") or i)
        naiss, deces = p.get("naissance"), p.get("deces")
        if p.get("inconnu"):
            dates, info = "non déclaré(e)", "Personne citée dans un lien mais absente de la base"
        else:
            dates = f"{naiss} – {deces}" if deces else f"{naiss}"
            info = f"{nom}\nNé(e) en {naiss}" + (f"\nDécédé(e) en {deces}" if deces else "\nVivant(e)")
        if p.get("en_erreur"):
            info += "\n⚠ impliqué(e) dans une incohérence"
        x, y = pos[i]
        net.add_node(i, label=f"{nom}\n{dates}", title=info, x=x, y=y, shape="box", color={
            "background": fond, "border": bord, "highlight": {"background": fond, "border": bord},
            "hover": {"background": fond, "border": bord}}, borderWidth=largeur_bord)

    # points d'union : un par ensemble de parents (couple)
    unions: dict[tuple, str] = {}
    gris, rose, or_ = "#9AA6C4", "#E58AB0", OR[1]
    aretes_conjoint = set()
    for l in liens:
        if l["type"] != "conjoint" or l["de"] not in pos or l["vers"] not in pos:
            continue
        cle = tuple(sorted((l["de"], l["vers"])))
        if cle in aretes_conjoint:
            continue
        aretes_conjoint.add(cle)
        sur = (cle[0], cle[1]) in paires_chemin
        net.add_edge(cle[0], cle[1], arrows="", color=or_ if sur else rose, width=3 if sur else 2,
                     title="mariage")

    for enfant, ps in parents.items():
        ps = [p for p in dict.fromkeys(ps) if p in pos]
        if not ps:
            continue
        if len(ps) == 2:
            cle = tuple(sorted(ps))
            if cle not in unions:
                uid = f"u_{cle[0]}_{cle[1]}"
                unions[cle] = uid
                ux = (pos[cle[0]][0] + pos[cle[1]][0]) / 2
                uy = max(pos[cle[0]][1], pos[cle[1]][1]) + DY * 0.5
                net.add_node(uid, label=" ", shape="dot", size=4, x=ux, y=uy, title="union",
                             color={"background": gris, "border": gris}, borderWidth=0,
                             shadow=False)
                for p in cle:
                    net.add_edge(p, uid, arrows="", color=gris, width=1.5)
            uid = unions[cle]
            sur = any((p, enfant) in paires_chemin for p in ps)
            net.add_edge(uid, enfant, color=or_ if sur else gris, width=3 if sur else 1.5,
                         arrows={"to": {"enabled": True, "scaleFactor": 0.6}})
        else:
            for p in ps:
                sur = (p, enfant) in paires_chemin
                net.add_edge(p, enfant, color=or_ if sur else gris, width=3 if sur else 1.5,
                             arrows={"to": {"enabled": True, "scaleFactor": 0.6}})
    html = net.generate_html()
    # fonctionne hors ligne : on retire la feuille de style / script Bootstrap (CDN) inutiles ici
    html = re.sub(r"<link[^>]*bootstrap[^>]*>", "", html)
    html = re.sub(r"<script[^>]*bootstrap[^>]*></script>", "", html)
    return html.replace("</body>", _SCRIPT_ZOOM.replace("__MIN__", str(ZOOM_MIN)).replace("__MAX__", str(ZOOM_MAX))
                        + "</body>")

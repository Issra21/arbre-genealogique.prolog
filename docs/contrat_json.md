# Contrat entre `cli.pl` (Prolog) et `pont.py` (Python)

Document de référence pour l'intégration. Proposé par Issra, à valider par Etienne.
Si un champ change, on met à jour ce fichier **et** `tests/test_cli.pl`.

## Appel

```
swipl cli.pl -- <fichier_faits> <commande> [arguments]
```

- À lancer depuis la racine du dépôt (ou avec le chemin complet de `cli.pl`).
- La réponse est **un objet JSON sur une ligne**, en **UTF-8**, sur la sortie standard.
- En cas d'erreur : `{"erreur": "message"}` et code de sortie `1`.
- Les identifiants de personnes sont des atomes Prolog en minuscules (`sami`, `nadia`).

Exemple côté Python :

```python
import json, subprocess

def appeler_prolog(fichier, *args):
    r = subprocess.run(["swipl", "cli.pl", "--", fichier, *args],
                       capture_output=True, encoding="utf-8")
    donnees = json.loads(r.stdout)
    if "erreur" in donnees:
        raise ValueError(donnees["erreur"])
    return donnees

graphe = appeler_prolog("donnees/famille.pl", "graphe")
lien = appeler_prolog("donnees/famille.pl", "relation", "nadia", "sami")
```

## Commandes

### `graphe` — à l'ouverture de la page

```json
{
  "personnes": [
    {"id": "sami", "nom": "Sami", "sexe": "h", "naissance": 1982, "deces": null,
     "en_erreur": false, "inconnu": false}
  ],
  "liens": [
    {"type": "parent",   "de": "maher", "vers": "sami"},
    {"type": "conjoint", "de": "sami",  "vers": "olfa"}
  ],
  "alertes": [
    {"code": "deces_avant_naissance", "personnes": ["d6"],
     "message": "Omar serait décédé(e) en 1980, avant sa naissance en 1990."}
  ],
  "stats": {"nb_personnes": 23, "nb_liens_parent": 28, "nb_mariages": 8, "nb_alertes": 0}
}
```

- `deces` vaut `null` si la personne est vivante.
- `en_erreur: true` → à colorer en rouge dans le graphe pyvis.
- `inconnu: true` → identifiant cité dans un lien mais jamais déclaré (`sexe`, `naissance` à `null`).
  Ces nœuds sont inclus pour que tous les liens aient leurs deux extrémités.
- Lien `parent` : `de` est le parent, `vers` l'enfant (flèche descendante).

### `alertes`

`{"alertes": [...]}`, même format que dans `graphe`.

### `relation X Y` — quand on choisit deux personnes

```json
{
  "x": "nadia", "y": "sami",
  "code": "oncle_tante",
  "fr": "tante paternelle", "ar": "عمّة",
  "phrase_fr": "Nadia est la tante paternelle de Sami.",
  "phrase_ar": "Nadia هي عمّة Sami",
  "degre_civil": 3,
  "cousinage": null,
  "ancetres_communs": ["habib", "zohra"],
  "chemin": [
    {"de": "nadia", "lien": "pere", "lien_fr": "père", "lien_ar": "أب", "vers": "habib"},
    {"de": "habib", "lien": "fils", "lien_fr": "fils", "lien_ar": "ابن", "vers": "maher"},
    {"de": "maher", "lien": "fils", "lien_fr": "fils", "lien_ar": "ابن", "vers": "sami"}
  ],
  "chemin_texte": "Nadia → père : Habib → fils : Maher → fils : Sami",
  "explication": {
    "texte": "Nadia est la tante paternelle de Sami. Raisonnement : ...",
    "etapes": ["Maher est le père de Sami", "Habib est le père de Nadia", "..."]
  }
}
```

- La relation se lit toujours « **X** est le/la `fr` de **Y** ».
- Un pas de `chemin` se lit « `vers` est le `lien_fr` de `de` ». Les `de`/`vers` servent à surligner le chemin dans le graphe.
- `cousinage` : `{"degre": 1, "ecart": 0}` pour des cousins (1 = germains, 2 = issus de germains), `null` sinon.
- `degre_civil` : `null` s'il n'y a pas d'ancêtre commun (lien par alliance).
- `explication.etapes` : liste pour le bouton « Pourquoi ? » (une ligne par étape).
- Valeurs possibles de `code` : `parent`, `grand_parent`, `arriere_grand_parent`, `enfant`, `petit_enfant`,
  `arriere_petit_enfant`, `frere_soeur`, `demi_frere_soeur`, `oncle_tante`, `grand_oncle_tante`,
  `neveu_niece`, `petit_neveu_niece`, `cousin_germain`, `cousin`, `cousin_eloigne`, `parent_eloigne`,
  `conjoint`, `beau_parent`, `gendre_belle_fille`, `oncle_tante_alliance`, `neveu_niece_alliance`,
  `beau_frere_soeur`, `alliance`, `aucun`.

### `expliquer X Y`

`{"x": ..., "y": ..., "texte": ..., "etapes": [...]}` — le même contenu que `relation.explication`.

### `liste <relation> X` — questions du sujet

Renvoie toutes les personnes R telles que « R est le/la `<relation>` de X ».

```
liste grand_pere sami      → « Qui est le grand-père de Sami ? »
liste cousin_germain sami  → « Quels sont ses cousins ? »
```

```json
{"relation": "cousin_germain", "personne": "sami",
 "resultats": [{"id": "amine", "nom": "Amine"}, {"id": "mariem", "nom": "Mariem"}]}
```

Relations disponibles : `pere`, `mere`, `parent`, `enfant`, `fils`, `fille`, `frere_ou_soeur`, `frere`, `soeur`,
`demi_frere_ou_soeur`, `grand_parent`, `grand_pere`, `grand_mere`, `petit_enfant`, `petit_fils`, `petite_fille`,
`oncle_ou_tante`, `oncle`, `tante`, `neveu_ou_niece`, `neveu`, `niece`, `cousin_germain`, `cousin`, `cousine`,
`ancetre`, `descendant`, `marie`.

## Erreurs

| Cas | Réponse |
| --- | --- |
| fichier de faits absent | `{"erreur": "fichier de faits introuvable : ..."}` |
| personne inconnue | `{"erreur": "personne inconnue : ..."}` |
| X = Y | `{"erreur": "les deux personnes doivent être différentes"}` |
| commande ou relation inconnue | `{"erreur": "commande inconnue ou arguments invalides"}` / `relation non disponible : ...` |

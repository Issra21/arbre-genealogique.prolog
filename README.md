# Système intelligent d'analyse des arbres généalogiques

Projet de la matière Programmation et Intelligence Artificielle .
Binôme : Issra Saidi, Etienne.

Le système représente une famille par des faits Prolog, déduit les liens de parenté
sur trois niveaux, détecte les incohérences dans les données et explique ses réponses
(« X est l'oncle de Y parce que… »). Une interface Streamlit affiche l'arbre sous forme
de graphe interactif.

## Architecture

```
Utilisateur (navigateur)
  └─ Streamlit + pyvis        graphe, formulaires          (Etienne)
       └─ pont.py             appelle swipl, lit le JSON   (Etienne)
            └─ cli.pl         commandes                    (Issra)
                 ├─ regles.pl       parenté, 3 niveaux
                 ├─ parente_ar.pl   termes FR / AR, chemin
                 ├─ coherence.pl    incohérences
                 └─ explication.pl  preuves
                      └─ donnees/*.pl   faits
```

## Format des faits

```prolog
personne(Id, Nom, Sexe, AnneeNaissance, AnneeDeces).  % Sexe : h | f ; AnneeDeces : année ou vivant
parent(Parent, Enfant).                                % lien biologique
conjoint(X, Y).                                        % déclaré une seule fois
```

- `donnees/famille.pl` : famille de test cohérente (23 personnes, 4 générations).
- `donnees/famille_erreurs.pl` : données volontairement fausses (erreurs E1 à E9) pour tester `coherence.pl`.

## Lancer

Prérequis : [SWI-Prolog](https://www.swi-prolog.org/download/stable), avec `swipl` dans le PATH.

```
swipl donnees/famille.pl regles.pl coherence.pl
?- cousin_germain(X, sami).
?- chemin(sami, hela, P).

swipl donnees/famille_erreurs.pl regles.pl coherence.pl
?- alertes(L).
```

Interface Prolog → Python (voir `docs/contrat_json.md`) :

```
swipl cli.pl -- donnees/famille.pl graphe
swipl cli.pl -- donnees/famille.pl relation nadia sami
swipl cli.pl -- donnees/famille.pl liste cousin_germain sami
```

Tests (Windows, depuis la racine) : `tests\lancer_tests.bat`, ou un fichier à la fois :
`swipl -g run_tests -t halt tests/test_niveau1.pl`.

## Règle du projet

Aucun copier-coller de code open source. Le dépôt
[corleone-family-tree](https://github.com/joao-tinelli/corleone-family-tree) sert seulement
de référence pour la liste des prédicats ; tout le code est écrit par le binôme.

:- encoding(utf8).
% =====================================================================
%  cli.pl -- Point d'entree appele par pont.py
%  Responsable : Issra (cote Prolog) / pont.py : Etienne
%
%  Usage :
%    swipl cli.pl -- <fichier_faits> graphe
%    swipl cli.pl -- <fichier_faits> alertes
%    swipl cli.pl -- <fichier_faits> relation <X> <Y>
%    swipl cli.pl -- <fichier_faits> expliquer <X> <Y>
%    swipl cli.pl -- <fichier_faits> liste <relation> <X>
%
%  Sortie : un objet JSON sur une ligne (UTF-8) sur la sortie standard.
%  En cas d'erreur : {"erreur": "..."} et code de sortie 1.
%  Le format exact de chaque reponse est decrit dans docs/contrat_json.md.
% =====================================================================

% library(json) dans les versions recentes de SWI-Prolog, library(http/json) avant.
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.

:- ensure_loaded(regles).
:- ensure_loaded(coherence).
:- ensure_loaded(parente_ar).
:- ensure_loaded(explication).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv0),
    arguments(Argv0, Argv),
    % UTF-8 quand la sortie est redirigee (pont.py) ; la console Windows
    % refuse ce changement mais affiche deja l'Unicode, on ignore l'erreur.
    catch(set_stream(user_output, encoding(utf8)), _, true),
    catch(executer(Argv), E, erreur(E)).

% arguments(Brut, Args) : garde ce qui suit "--" et retire le nom du
% programme s'il est encore present (selon la version de SWI-Prolog).
arguments(Av0, Av) :-
    (   append(_, ['--'|Av1], Av0) -> true ; Av1 = Av0 ),
    (   Av1 = [P|Reste], file_base_name(P, B), sub_atom(B, 0, _, _, swipl)
    ->  Av = Reste
    ;   Av = Av1
    ).

executer([Fichier, Cmd|Args]) :- !,
    charger(Fichier),
    (   commande(Cmd, Args, Reponse)
    ->  json_write_dict(current_output, Reponse, [width(0)]), nl
    ;   throw(erreur('commande inconnue ou arguments invalides'))
    ).
executer(_) :-
    throw(erreur('usage : swipl cli.pl -- <fichier_faits> <commande> [arguments]')).

erreur(E) :-
    (   E = erreur(M) -> true
    ;   format(atom(M), '~q', [E])
    ),
    json_write_dict(current_output, _{erreur: M}, [width(0)]), nl,
    halt(1).

% charger(Fichier) : charge les faits ; les predicats absents du fichier
% (ex. aucun mariage) sont crees vides pour que les regles marchent.
charger(Fichier) :-
    (   exists_file(Fichier) -> true
    ;   format(atom(M), 'fichier de faits introuvable : ~w', [Fichier]),
        throw(erreur(M))
    ),
    load_files(Fichier, [silent(true)]),
    forall(member(P, [personne/5, parent/2, conjoint/2]),
           ( current_predicate(P) -> true ; dynamic(P) )).


% =====================================================================
%  Commandes
% =====================================================================

% graphe : tout ce qu'il faut a l'ouverture de la page.
commande(graphe, [], _{personnes: Ps, liens: Ls, alertes: As, stats: St}) :-
    personnes_en_erreur(Rouges),
    tous_les_ids(Ids),
    maplist(personne_json(Rouges), Ids, Ps),
    findall(_{type: parent, de: P, vers: E}, parent(P, E), L1),
    findall(_{type: conjoint, de: X, vers: Y}, conjoint(X, Y), L2),
    append(L1, L2, Ls),
    alertes_json(As),
    length(Ids, NP), length(L1, NL), length(L2, NM), length(As, NA),
    St = _{nb_personnes: NP, nb_liens_parent: NL, nb_mariages: NM, nb_alertes: NA}.

% alertes : seulement les incoherences.
commande(alertes, [], _{alertes: As}) :-
    alertes_json(As).

% relation X Y : lien, degres, chemin et explication.
commande(relation, [X, Y], R) :-
    connue(X), connue(Y), differentes(X, Y),
    relation(X, Y, Code, Fr, Ar),
    phrase_relation(X, Y, PFr, PAr),
    (   degre_civil(X, Y, DC) -> true ; DC = null ),
    (   degre_cousinage(X, Y, DCo, Ec) -> Cous = _{degre: DCo, ecart: Ec}
    ;   Cous = null
    ),
    (   ancetres_communs_proches(X, Y, L) -> findall(A, member(a(A, _, _), L), ACs)
    ;   ACs = []
    ),
    (   chemin(X, Y, Pas)
    ->  maplist(pas_json, Pas, Chemin), chemin_texte(X, Y, CT)
    ;   Chemin = [], CT = null
    ),
    explication_json(X, Y, Expl),
    R = _{x: X, y: Y, code: Code, fr: Fr, ar: Ar,
          phrase_fr: PFr, phrase_ar: PAr,
          degre_civil: DC, cousinage: Cous,
          ancetres_communs: ACs,
          chemin: Chemin, chemin_texte: CT,
          explication: Expl}.

% expliquer X Y : seulement l'explication.
commande(expliquer, [X, Y], R) :-
    connue(X), connue(Y), differentes(X, Y),
    explication_json(X, Y, E),
    put_dict(_{x: X, y: Y}, E, R).

% liste Relation X : toutes les personnes R telles que Relation(R, X).
%   ex. liste grand_pere sami -> "qui est le grand-pere de Sami ?"
%       liste cousin_germain sami -> "quels sont ses cousins ?"
commande(liste, [Rel, X], _{relation: Rel, personne: X, resultats: Rs}) :-
    connue(X),
    (   relation_listable(Rel) -> true
    ;   format(atom(M), 'relation non disponible : ~w', [Rel]), throw(erreur(M))
    ),
    But =.. [Rel, R, X],
    (   setof(R, But, Ids) -> true ; Ids = [] ),
    findall(_{id: I, nom: N}, (member(I, Ids), nom(I, N)), Rs).

relation_listable(Rel) :-
    memberchk(Rel, [ pere, mere, parent, enfant, fils, fille,
                     frere_ou_soeur, frere, soeur, demi_frere_ou_soeur,
                     grand_parent, grand_pere, grand_mere,
                     petit_enfant, petit_fils, petite_fille,
                     oncle_ou_tante, oncle, tante, neveu_ou_niece, neveu, niece,
                     cousin_germain, cousin, cousine,
                     ancetre, descendant, marie ]).


% =====================================================================
%  Conversion en JSON
% =====================================================================

tous_les_ids(Ids) :-
    (   setof(X, id_cite(X), Ids) -> true ; Ids = [] ).

id_cite(X) :- personne(X, _, _, _, _).
id_cite(X) :- parent(X, _).
id_cite(X) :- parent(_, X).
id_cite(X) :- conjoint(X, _).
id_cite(X) :- conjoint(_, X).

personne_json(Rouges, Id, J) :-
    (   personne(Id, Nom, S, N, D)
    ->  ( D == vivant -> DJ = null ; DJ = D ),
        Inconnu = false
    ;   Nom = Id, S = null, N = null, DJ = null, Inconnu = true
    ),
    ( memberchk(Id, Rouges) -> Err = true ; Err = false ),
    J = _{id: Id, nom: Nom, sexe: S, naissance: N, deces: DJ,
          en_erreur: Err, inconnu: Inconnu}.

alertes_json(As) :-
    alertes(L),
    findall(_{code: C, personnes: Ps, message: M}, member(alerte(C, Ps, M), L), As).

pas_json(pas(De, Lien, Vers), _{de: De, lien: Lien, lien_fr: Fr, lien_ar: Ar, vers: Vers}) :-
    lien_pas(Lien, Fr, Ar).

explication_json(X, Y, _{texte: T, etapes: Es}) :-
    (   expliquer(X, Y, T, Es) -> true
    ;   T = null, Es = []
    ).

connue(X) :-
    (   personne(X, _, _, _, _) -> true
    ;   format(atom(M), 'personne inconnue : ~w', [X]), throw(erreur(M))
    ).

differentes(X, Y) :-
    (   X \== Y -> true
    ;   throw(erreur('les deux personnes doivent être différentes'))
    ).

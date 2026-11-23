:- encoding(utf8).
% =====================================================================
%  explication.pl -- Meta-interpreteur qui produit les preuves
%  Responsable : Issra
%
%  Se charge apres les donnees, regles.pl et parente_ar.pl.
%
%  Idee : au lieu d'appeler directement une regle (ex. tante(nadia, sami)),
%  on la "rejoue" clause par clause avec prouve/2, qui note chaque fait
%  utilise et chaque conclusion intermediaire. On obtient un arbre de
%  preuve, qu'on traduit ensuite en phrases.
%
%  Predicats utiles pour l'interface :
%    prouve(But, Preuve)            arbre de preuve d'un but
%    expliquer(X, Y, Texte, Etapes) "Nadia est la tante ... parce que ..."
% =====================================================================


% =====================================================================
%  Meta-interpreteur : prouve(But, Preuve)
%  Preuve = liste de noeuds :
%    fait(F)            un fait de la base (parent/2, conjoint/2, personne/5)
%    deduit(But, Sous)  une regle du projet, prouvee par les noeuds Sous
% =====================================================================

prouve(true, []) :- !.
prouve((A, B), P) :- !,
    prouve(A, PA), prouve(B, PB), append(PA, PB, P).
prouve((C -> T ; E), P) :- !,
    (   prouve(C, PC) -> prouve(T, PT), append(PC, PT, P)
    ;   prouve(E, P)
    ).
prouve((A ; B), P) :- !,
    (   prouve(A, P) ; prouve(B, P) ).
prouve(\+ G, []) :- !,
    \+ call(G).
prouve(distinct(_, G), P) :- !,          % on explique la premiere preuve
    prouve(G, P).
prouve(G, [fait(G)]) :-
    fait_de_base(G), !,
    call(G).
prouve(G, [deduit(G, P)]) :-
    regle_expliquee(G), !,
    clause(G, Corps),
    prouve(Corps, P).
prouve(G, []) :-                          % tests (\==, @<, is, ...) : pas affiches
    call(G).

fait_de_base(parent(_, _)).
fait_de_base(conjoint(_, _)).
fait_de_base(personne(_, _, _, _, _)).

% Regles de regles.pl que le meta-interpreteur deroule.
% (ancetre/2 n'y est pas : il est table, et les liens lointains sont
% expliques par le chemin, voir plus bas.)
regle_expliquee(G) :-
    functor(G, N, A),
    memberchk(N/A, [ homme/1, femme/1, marie/2,
                     pere/2, mere/2, enfant/2, fils/2, fille/2,
                     frere_ou_soeur/2, germains/2, demi_frere_ou_soeur/2,
                     frere/2, soeur/2,
                     grand_parent/2, grand_pere/2, grand_mere/2,
                     petit_enfant/2, petit_fils/2, petite_fille/2,
                     oncle_tante_sang/2, oncle_tante_alliance/2,
                     oncle_ou_tante/2, oncle/2, tante/2,
                     neveu_ou_niece/2, neveu/2, niece/2,
                     cousin_germain/2, cousin/2, cousine/2 ]).


% =====================================================================
%  expliquer(X, Y, Texte, Etapes)
% =====================================================================

expliquer(X, Y, Texte, Etapes) :-
    relation(X, Y, Code, _, _),
    phrase_relation(X, Y, Phrase, _),
    (   Code == aucun
    ->  Etapes = [], Texte = Phrase
    ;   but_a_prouver(Code, X, Y, But),
        once(prouve(But, Preuve))
    ->  etapes_preuve(Preuve, Etapes0), list_to_set(Etapes0, Etapes),
        atomic_list_concat(Etapes, ' ; ', Suite),
        format(atom(Texte), '~w Raisonnement : ~w.', [Phrase, Suite])
    ;   % lien lointain : on montre les faits le long du chemin
        chemin(X, Y, Pas),
        maplist(pas_vers_phrase, Pas, Etapes),
        chemin_texte(X, Y, CT),
        format(atom(Texte), '~w Chemin : ~w.', [Phrase, CT])
    ).

% but_a_prouver(Code, X, Y, But) : la regle de regles.pl qui correspond
% au lien trouve par parente_ar.pl (masculin ou feminin selon X).
but_a_prouver(Code, X, Y, But) :-
    sexe(X, S),
    but(Code, S, X, Y, But).

but(parent,               S, X, Y, B) :- g(S, pere(X, Y), mere(X, Y), B).
but(grand_parent,         S, X, Y, B) :- g(S, grand_pere(X, Y), grand_mere(X, Y), B).
but(enfant,               S, X, Y, B) :- g(S, fils(X, Y), fille(X, Y), B).
but(petit_enfant,         S, X, Y, B) :- g(S, petit_fils(X, Y), petite_fille(X, Y), B).
but(frere_soeur,          S, X, Y, B) :- g(S, frere(X, Y), soeur(X, Y), B).
but(demi_frere_soeur,     S, X, Y, B) :- g(S, frere(X, Y), soeur(X, Y), B).
but(oncle_tante,          S, X, Y, B) :- g(S, oncle(X, Y), tante(X, Y), B).
but(oncle_tante_alliance, S, X, Y, B) :- g(S, oncle(X, Y), tante(X, Y), B).
but(neveu_niece,          S, X, Y, B) :- g(S, neveu(X, Y), niece(X, Y), B).
but(cousin_germain,       S, X, Y, B) :- g(S, cousin(X, Y), cousine(X, Y), B).
but(conjoint,             _, X, Y, marie(X, Y)).


% =====================================================================
%  Traduction de l'arbre de preuve en phrases
%  Parcours en profondeur : d'abord les faits, puis la conclusion
%  intermediaire qu'ils permettent.
% =====================================================================

etapes_preuve([], []).
etapes_preuve([N|Ns], Etapes) :-
    etapes_noeud(N, E1),
    etapes_preuve(Ns, E2),
    append(E1, E2, Etapes).

etapes_noeud(fait(F), [T]) :-
    phrase_fait(F, T), !.
etapes_noeud(fait(_), []).
etapes_noeud(deduit(G, Sous), Etapes) :-
    etapes_preuve(Sous, E1),
    (   conclusion(G, C) -> append(E1, [C], Etapes)
    ;   Etapes = E1
    ).

% Phrases pour les faits.
phrase_fait(parent(A, B), T) :-
    nom(A, NA), nom(B, NB), de(NB, DeB),
    ( sexe(A, S) -> true ; S = h ),
    g(S, 'le père', 'la mère', Role),
    format(atom(T), '~w est ~w ~w', [NA, Role, DeB]).
phrase_fait(conjoint(A, B), T) :-
    nom(A, NA), nom(B, NB),
    format(atom(T), '~w et ~w sont mariés', [NA, NB]).
phrase_fait(personne(_, Nom, S, _, _), T) :-
    g(S, 'un homme', 'une femme', Mot),
    format(atom(T), '~w est ~w', [Nom, Mot]).

% Conclusions intermediaires (les autres regles restent implicites).
conclusion(frere_ou_soeur(A, B), T) :-
    nom(A, NA), nom(B, NB), fratrie(A, B, Mot),
    format(atom(T), 'donc ~w et ~w sont ~w', [NA, NB, Mot]).
conclusion(oncle_tante_sang(A, B), T) :-
    nom(A, NA), nom(B, NB), de(NB, DeB),
    format(atom(T), 'donc ~w est frère ou sœur d\'un parent ~w', [NA, DeB]).
conclusion(oncle_tante_alliance(A, B), T) :-
    nom(A, NA), nom(B, NB), de(NB, DeB),
    format(atom(T), 'donc ~w est marié(e) à un frère ou une sœur d\'un parent ~w', [NA, DeB]).
conclusion(grand_parent(A, B), T) :-
    nom(A, NA), nom(B, NB), de(NB, DeB),
    format(atom(T), 'donc ~w est un grand-parent ~w', [NA, DeB]).

fratrie(A, B, Mot) :-
    ( sexe(A, SA) -> true ; SA = h ),
    ( sexe(B, SB) -> true ; SB = h ),
    (   SA == h, SB == h -> Mot = 'frères'
    ;   SA == f, SB == f -> Mot = 'sœurs'
    ;   Mot = 'frère et sœur'
    ).

% Un pas du chemin, traduit comme le fait qu'il utilise.
pas_vers_phrase(pas(De, Lien, V), T) :-
    (   memberchk(Lien, [pere, mere])  -> phrase_fait(parent(V, De), T)
    ;   memberchk(Lien, [fils, fille]) -> phrase_fait(parent(De, V), T)
    ;   phrase_fait(conjoint(De, V), T)
    ).

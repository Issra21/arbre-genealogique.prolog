% =====================================================================
%  tests/test_niveau3.pl -- Tests des regles du niveau 3
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_niveau3.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille.pl').
:- ensure_loaded('../regles.pl').

:- begin_tests(niveau3).

% --- Ancetres / descendants ------------------------------------------
test(ancetres_de_adam,
     [true(L == [aicha, habib, leila, maher, mokhtar, olfa, sami, zohra])]) :-
    setof(A, ancetre(A, adam), L).
test(descendants_de_mokhtar,
     [true(L == [adam, faouzi, ines, leila, lina, mariem, sami])]) :-
    setof(D, descendant(D, mokhtar), L).
test(habib_arriere_grand_pere_de_adam, [nondet]) :-
    ancetre(habib, adam, 3).
test(generations_vers_adam, [true(L == [1-olfa, 1-sami, 2-leila, 2-maher,
                                         3-aicha, 3-habib, 3-mokhtar, 3-zohra])]) :-
    setof(N-A, ancetre(A, adam, N), L).
test(pas_son_propre_ancetre, [fail]) :-
    ancetre(sami, sami).

% --- Ancetres communs les plus proches -------------------------------
test(ancetres_communs_sami_amine,
     [true(L == [a(habib, 2, 2), a(zohra, 2, 2)])]) :-
    ancetres_communs_proches(sami, amine, L).
test(ancetre_commun_pere_fils, [true(L == [a(maher, 1, 0)])]) :-
    ancetres_communs_proches(sami, maher, L).
test(pas_d_ancetre_commun_par_alliance, [fail]) :-
    ancetres_communs_proches(sami, olfa, _).

% --- Degre civil --------------------------------------------------------
test(degre_pere,          [true(D == 1)]) :- degre_civil(sami, maher, D).
test(degre_soeur,         [true(D == 2)]) :- degre_civil(sami, ines, D).
test(degre_tante,         [true(D == 3)]) :- degre_civil(sami, nadia, D).
test(degre_cousin,        [true(D == 4)]) :- degre_civil(sami, amine, D).

% --- Degre de cousinage ----------------------------------------------
test(cousins_germains,           [true(D-E == 1-0)]) :-
    degre_cousinage(sami, amine, D, E).
test(cousins_issus_de_germains,  [true(D-E == 2-0)]) :-
    degre_cousinage(adam, yassine, D, E).
test(cousin_une_generation_ecart, [true(D-E == 1-1)]) :-
    degre_cousinage(adam, amine, D, E).
test(tante_pas_cousine, [fail]) :-
    degre_cousinage(sami, nadia, _, _).

% --- Chemin de parente ------------------------------------------------
test(chemin_pere_fils, [true(P == [pas(maher, fils, sami)])]) :-
    chemin(maher, sami, P).
test(chemin_cousin, [true(P == [pas(sami, pere, maher), pas(maher, pere, habib),
                                pas(habib, fille, nadia), pas(nadia, fils, amine)])]) :-
    chemin(sami, amine, P).
test(chemin_par_alliance,
     [true(P == [pas(sami, mere, leila), pas(leila, pere, mokhtar),
                 pas(mokhtar, fils, faouzi), pas(faouzi, epouse, hela)])]) :-
    chemin(sami, hela, P).
test(chemin_vers_soi, [fail]) :-
    chemin(sami, sami, _).

:- end_tests(niveau3).

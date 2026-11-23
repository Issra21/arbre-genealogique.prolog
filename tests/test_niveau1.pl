% =====================================================================
%  tests/test_niveau1.pl -- Tests des regles du niveau 1
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_niveau1.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille.pl').
:- ensure_loaded('../regles.pl').

:- begin_tests(niveau1).

% --- Pere / mere ------------------------------------------------------
test(pere_de_sami)          :- pere(maher, sami).
test(mere_de_sami)          :- mere(leila, sami).
test(leila_pas_pere, [fail]) :- pere(leila, sami).
test(parents_de_sami, [true(Ps == [leila, maher])]) :-
    setof(P, parent(P, sami), Ps).

% --- Enfant / fils / fille -------------------------------------------
test(enfants_de_habib, [true(Es == [kamel, maher, nadia])]) :-
    setof(E, enfant(E, habib), Es).
test(fils_de_maher, [true(Fs == [sami])]) :-
    setof(F, fils(F, maher), Fs).
test(fille_de_maher, [true(Fs == [ines])]) :-
    setof(F, fille(F, maher), Fs).

% --- Fratrie ---------------------------------------------------------
test(frere_de_ines, [nondet]) :- frere(sami, ines).
test(soeur_de_sami, [nondet]) :- soeur(ines, sami).
test(pas_son_propre_frere, [fail]) :- frere(sami, sami).
test(fratrie_de_maher, [true(Fs == [kamel, nadia])]) :-
    setof(F, frere_ou_soeur(F, maher), Fs).
test(pas_de_doublon, [true(N == 1)]) :-
    findall(x, frere_ou_soeur(rim, amine), L), length(L, N).
test(germains, [nondet])     :- germains(amine, rim).
test(aucun_demi_frere, [fail]) :- demi_frere_ou_soeur(_, _).
test(cousins_pas_freres, [fail]) :- frere_ou_soeur(sami, amine).

% --- Mariage ---------------------------------------------------------
test(mariage_symetrique, [nondet]) :- marie(leila, maher), marie(maher, leila).

:- end_tests(niveau1).

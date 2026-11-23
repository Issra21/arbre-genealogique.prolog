% =====================================================================
%  tests/test_niveau2.pl -- Tests des regles du niveau 2
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_niveau2.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille.pl').
:- ensure_loaded('../regles.pl').

:- begin_tests(niveau2).

% --- Grands-parents (exemple du sujet : "Qui est le grand-pere de X ?")
test(grands_parents_de_sami, [true(L == [aicha, habib, mokhtar, zohra])]) :-
    setof(G, grand_parent(G, sami), L).
test(grands_peres_de_sami, [true(L == [habib, mokhtar])]) :-
    setof(G, grand_pere(G, sami), L).
test(grands_parents_de_adam, [true(L == [leila, maher])]) :-
    setof(G, grand_parent(G, adam), L).
test(petits_enfants_de_habib, [true(L == [amine, ines, rim, sami, youssef])]) :-
    setof(E, petit_enfant(E, habib), L).
test(petites_filles_de_habib, [true(L == [ines, rim])]) :-
    setof(E, petite_fille(E, habib), L).

% --- Oncles et tantes -------------------------------------------------
test(oncles_tantes_sang_de_sami, [true(L == [faouzi, kamel, nadia])]) :-
    setof(X, oncle_tante_sang(X, sami), L).
test(oncles_tantes_alliance_de_sami, [true(L == [hela, rached, samia])]) :-
    setof(X, oncle_tante_alliance(X, sami), L).
test(oncles_de_sami, [true(L == [faouzi, kamel, rached])]) :-
    setof(X, oncle(X, sami), L).
test(tantes_de_sami, [true(L == [hela, nadia, samia])]) :-
    setof(X, tante(X, sami), L).
test(rached_pas_oncle_de_sang, [fail]) :-
    oncle_tante_sang(rached, sami).
test(pere_pas_oncle, [fail]) :-
    oncle_ou_tante(maher, sami).

% --- Neveux et nieces -------------------------------------------------
test(neveux_nieces_de_nadia, [true(L == [ines, sami, youssef])]) :-
    setof(N, neveu_ou_niece(N, nadia), L).
test(neveux_nieces_de_hela, [true(L == [ines, sami])]) :-
    setof(N, neveu_ou_niece(N, hela), L).

% --- Cousins (exemple du sujet : "Quels sont ses cousins ?") ----------
test(cousins_germains_de_sami, [true(L == [amine, mariem, rim, youssef])]) :-
    setof(C, cousin_germain(C, sami), L).
test(cousines_de_sami, [true(L == [mariem, rim])]) :-
    setof(C, cousine(C, sami), L).
test(cousinage_symetrique, [nondet]) :-
    cousin_germain(sami, amine), cousin_germain(amine, sami).
test(adam_sans_cousin_germain, [fail]) :-
    cousin_germain(_, adam).
test(issus_de_germains_pas_germains, [fail]) :-
    cousin_germain(adam, yassine).

:- end_tests(niveau2).

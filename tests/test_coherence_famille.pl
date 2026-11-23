% =====================================================================
%  tests/test_coherence_famille.pl -- la famille de test est saine
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_coherence_famille.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille.pl').
:- ensure_loaded('../regles.pl').
:- ensure_loaded('../coherence.pl').

:- begin_tests(coherence_famille).

test(aucune_incoherence, [fail]) :-
    incoherence(_, _).
test(aucune_personne_en_rouge, [true(L == [])]) :-
    personnes_en_erreur(L).

:- end_tests(coherence_famille).

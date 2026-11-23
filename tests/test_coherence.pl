:- encoding(utf8).
% =====================================================================
%  tests/test_coherence.pl -- coherence.pl sur les donnees fausses
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_coherence.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille_erreurs.pl').
:- ensure_loaded('../regles.pl').
:- ensure_loaded('../coherence.pl').

:- begin_tests(coherence).

% --- Toutes les erreurs E1 a E11 sont detectees, et rien de plus ------
test(liste_complete, [true(L == [
        cycle-[x1, x2, x3],
        deces_avant_naissance-[d6],
        longevite_impossible-[v10],
        mariage_ascendant-[p8, e8],
        mariage_fratrie-[f9, s9],
        naissance_apres_deces_mere-[m7, e7],
        parent_plus_jeune-[p2, e2],
        parent_plus_jeune-[x3, x1],
        parent_trop_jeune-[p3, e3],
        reference_inconnue-[z11],
        sexe_contradictoire-[s5],
        trop_de_parents-[e4, a4, b4, c4]
    ])]) :-
    setof(C-P, incoherence(C, P), L).

% --- Une erreur a la fois ---------------------------------------------
test(e1_cycle, [nondet])                 :- incoherence(cycle, [x1, x2, x3]).
test(e2_parent_plus_jeune, [nondet])     :- incoherence(parent_plus_jeune, [p2, e2]).
test(e3_parent_trop_jeune, [nondet])     :- incoherence(parent_trop_jeune, [p3, e3]).
test(e4_trop_de_parents, [nondet])       :- incoherence(trop_de_parents, [e4, a4, b4, c4]).
test(e5_sexe_contradictoire, [nondet])   :- incoherence(sexe_contradictoire, [s5]).
test(e6_deces_avant_naissance, [nondet]) :- incoherence(deces_avant_naissance, [d6]).
test(e7_naissance_apres_deces, [nondet]) :- incoherence(naissance_apres_deces_mere, [m7, e7]).
test(e8_mariage_ascendant, [nondet])     :- incoherence(mariage_ascendant, [p8, e8]).
test(e9_mariage_fratrie, [nondet])       :- incoherence(mariage_fratrie, [f9, s9]).
test(e10_longevite, [nondet])            :- incoherence(longevite_impossible, [v10]).
test(e11_reference_inconnue, [nondet])   :- incoherence(reference_inconnue, [z11]).

% --- Les regles terminent malgre le cycle -----------------------------
test(ancetre_termine_sur_cycle, [true(L == [x1, x2, x3])]) :-
    setof(A, ancetre(A, x1), L).

% --- Messages et synthese ---------------------------------------------
test(message_deces, [true(T == 'Omar serait décédé(e) en 1980, avant sa naissance en 1990.')]) :-
    message(deces_avant_naissance, [d6], T).
test(message_fratrie, [true(T == 'Bilel et Dorra sont mariés alors qu\'ils sont frère et sœur.')]) :-
    message(mariage_fratrie, [f9, s9], T).
test(une_alerte_par_incoherence, [true(N == 12)]) :-
    alertes(L), length(L, N).
test(personnes_en_rouge, [true(L == [a4, b4, c4, d6, e2, e3, e4, e7, e8, f9, m7,
                                      p2, p3, p8, s5, s9, v10, x1, x2, x3, z11])]) :-
    personnes_en_erreur(L).

:- end_tests(coherence).

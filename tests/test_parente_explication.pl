:- encoding(utf8).
% =====================================================================
%  tests/test_parente_explication.pl -- parente_ar.pl et explication.pl
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_parente_explication.pl
% =====================================================================

:- use_module(library(plunit)).
:- ensure_loaded('../donnees/famille.pl').
:- ensure_loaded('../regles.pl').
:- ensure_loaded('../coherence.pl').
:- ensure_loaded('../parente_ar.pl').
:- ensure_loaded('../explication.pl').

:- begin_tests(parente).

% relation(X, Y, Code, Fr, Ar) : "X est le <Fr> de Y"
rel(X, Y, Code-Fr-Ar) :- relation(X, Y, Code, Fr, Ar).

test(pere,            [true(R == parent-'père'-'أب')])                    :- rel(sami, adam, R).
test(tante_paternelle, [true(R == oncle_tante-'tante paternelle'-'عمّة')]) :- rel(nadia, sami, R).
test(oncle_maternel,  [true(R == oncle_tante-'oncle maternel'-'خال')])    :- rel(faouzi, sami, R).
test(neveu,           [true(R == neveu_niece-'neveu'-'ابن الأخ')])         :- rel(sami, nadia, R).
test(soeur,           [true(R == frere_soeur-'sœur'-'أخت')])              :- rel(ines, sami, R).
test(cousin_cote_tante_paternelle,
     [true(R == cousin_germain-'cousin germain'-'ابن العمّة')])           :- rel(amine, sami, R).
test(cousine_cote_oncle_maternel,
     [true(R == cousin_germain-'cousine germaine'-'بنت الخال')])          :- rel(mariem, sami, R).
test(arriere_grand_pere,
     [true(R == arriere_grand_parent-'arrière-grand-père'-'جد من الجيل 3')]) :- rel(habib, adam, R).
test(arriere_petit_fils,
     [true(R == arriere_petit_enfant-'arrière-petit-fils'-'حفيد من الجيل 3')]) :- rel(adam, habib, R).
test(issu_de_germain,
     [true(R == cousin-'cousin issu de germain'-'قريب من الدرجة 6')])     :- rel(adam, yassine, R).
test(cousin_eloigne,
     [true(R == cousin_eloigne-'cousin éloigné (1 génération d\'écart)'-'قريب من الدرجة 5')]) :-
    rel(adam, amine, R).
test(epoux,           [true(R == conjoint-'époux'-'زوج')])                :- rel(sami, olfa, R).
test(oncle_alliance,  [true(R == oncle_tante_alliance-'oncle par alliance'-'زوج العمّة')]) :- rel(rached, sami, R).
test(tante_alliance,  [true(R == oncle_tante_alliance-'tante par alliance'-'زوجة الخال')]) :- rel(hela, sami, R).
test(neveu_alliance,  [true(R == neveu_niece_alliance-'neveu par alliance'-'ابن أخ الزوجة')]) :- rel(sami, rached, R).
test(belle_mere,      [true(R == beau_parent-'belle-mère'-'حماة')])       :- rel(leila, olfa, R).
test(belle_fille,     [true(R == gendre_belle_fille-'belle-fille'-'كنّة')]) :- rel(olfa, leila, R).
test(belle_soeur,     [true(R == beau_frere_soeur-'belle-sœur'-'نسيبة')])  :- rel(samia, maher, R).
test(alliance_lointaine, [true(R == alliance-'parent par alliance'-'نسيب')]) :- rel(kamel, hela, R).

test(phrase_tante, [true(F-A == 'Nadia est la tante paternelle de Sami.'-'Nadia هي عمّة Sami')]) :-
    phrase_relation(nadia, sami, F, A).
test(phrase_elision_article, [true(F == 'Faouzi est l\'oncle maternel de Sami.')]) :-
    phrase_relation(faouzi, sami, F, _).
test(phrase_elision_de, [true(F == 'Sami est le frère d\'Ines.')]) :-
    phrase_relation(sami, ines, F, _).
test(chemin_texte, [true(T == 'Sami → père : Maher → père : Habib → fille : Nadia → fils : Amine')]) :-
    chemin_texte(sami, amine, T).

:- end_tests(parente).


:- begin_tests(explication).

test(preuve_tante, [true(E == [ 'Maher est le père de Sami',
                                'Habib est le père de Nadia',
                                'Habib est le père de Maher',
                                'donc Nadia et Maher sont frère et sœur',
                                'donc Nadia est frère ou sœur d\'un parent de Sami',
                                'Nadia est une femme' ])]) :-
    expliquer(nadia, sami, _, E).
test(texte_tante, [true(sub_atom(T, 0, _, _, 'Nadia est la tante paternelle de Sami. Raisonnement : '))]) :-
    expliquer(nadia, sami, T, _).
test(preuve_oncle_alliance, [true((memberchk('Rached et Nadia sont mariés', E),
                                   last(E, 'Rached est un homme')))]) :-
    expliquer(rached, sami, _, E).
test(preuve_mariage, [true(E == ['Sami et Olfa sont mariés'])]) :-
    expliquer(sami, olfa, _, E).
test(lien_lointain_par_chemin, [true(E == [ 'Habib est le père de Maher',
                                            'Maher est le père de Sami',
                                            'Sami est le père d\'Adam' ])]) :-
    expliquer(habib, adam, _, E).
test(meta_interpreteur_fait, [true(P == [fait(parent(maher, sami))])]) :-
    prouve(parent(maher, sami), P).

:- end_tests(explication).

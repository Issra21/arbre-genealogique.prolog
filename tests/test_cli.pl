:- encoding(utf8).
% =====================================================================
%  tests/test_cli.pl -- cli.pl de bout en bout, comme le fera pont.py :
%  on lance "swipl cli.pl -- <faits> <commande>" et on lit le JSON.
%  Lancer depuis la racine du projet :
%    swipl -g run_tests -t halt tests/test_cli.pl
% =====================================================================

:- use_module(library(plunit)).
:- use_module(library(process)).
% library(json) dans les versions recentes de SWI-Prolog, library(http/json) avant.
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.

:- prolog_load_context(directory, D),
   file_directory_name(D, Racine),
   asserta(racine(Racine)).

% cli(Args, Dict) : lance cli.pl avec Args et lit la reponse JSON.
cli(Args, Dict) :-
    racine(R),
    process_create(path(swipl), ['cli.pl', '--'|Args],
                   [cwd(R), stdout(pipe(Out)), stderr(null), process(Pid)]),
    set_stream(Out, encoding(utf8)),
    json_read_dict(Out, Dict),
    close(Out),
    process_wait(Pid, _).

:- begin_tests(cli).

test(graphe_famille, [true(N-A == 23-0)]) :-
    cli(['donnees/famille.pl', graphe], D),
    length(D.personnes, N), length(D.alertes, A).
test(graphe_erreurs, [true(N-A == 24-12)]) :-     % 23 personnes + z11 inconnu
    cli(['donnees/famille_erreurs.pl', graphe], D),
    length(D.personnes, N), length(D.alertes, A).
test(relation_tante, [true(C-F-Ar == "oncle_tante"-"tante paternelle"-"عمّة")]) :-
    cli(['donnees/famille.pl', relation, nadia, sami], D),
    C = D.code, F = D.fr, Ar = D.ar.
test(relation_chemin, [true(N == 4)]) :-
    cli(['donnees/famille.pl', relation, sami, amine], D),
    length(D.chemin, N).
test(liste_cousins, [true(Ids == ["amine", "mariem", "rim", "youssef"])]) :-
    cli(['donnees/famille.pl', liste, cousin_germain, sami], D),
    findall(I, (member(R, D.resultats), I = R.id), Ids).
test(personne_inconnue, [true(get_dict(erreur, D, _))]) :-
    cli(['donnees/famille.pl', relation, sami, personne_qui_n_existe_pas], D).

:- end_tests(cli).

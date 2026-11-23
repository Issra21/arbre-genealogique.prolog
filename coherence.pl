:- encoding(utf8).
% =====================================================================
%  coherence.pl -- Detection des incoherences par contraintes
%  Responsable : Issra
%
%  Se charge apres les donnees et regles.pl :
%    swipl donnees/famille_erreurs.pl regles.pl coherence.pl
%
%  Predicats utiles pour l'interface :
%    incoherence(Code, Personnes)   une alerte (Personnes = ids concernes)
%    message(Code, Personnes, Texte) phrase lisible pour l'utilisateur
%    alertes(L)                     liste de alerte(Code, Personnes, Texte)
%    personnes_en_erreur(L)         ids a colorer en rouge dans le graphe
%
%  Codes : cycle, parent_plus_jeune, parent_trop_jeune, trop_de_parents,
%          sexe_contradictoire, deces_avant_naissance,
%          naissance_apres_deces_mere, naissance_apres_deces_pere,
%          longevite_impossible, mariage_ascendant, mariage_fratrie,
%          reference_inconnue
% =====================================================================

% --- Parametres -------------------------------------------------------

ecart_min_parent(12).      % age minimum d'un parent a la naissance
longevite_max(120).        % age maximum plausible

% --- Acces aux donnees ------------------------------------------------

naissance(X, N) :- personne(X, _, _, N, _).
deces(X, D)     :- personne(X, _, _, _, D), integer(D).

annee_courante(A) :-
    get_time(T),
    stamp_date_time(T, date(A, _, _, _, _, _, _, _, _), local).


% =====================================================================
%  Contraintes : incoherence(Code, Personnes)
% =====================================================================

% Une personne est son propre ancetre : on regroupe tout le cycle.
incoherence(cycle, Membres) :-
    distinct(Membres,
             ( ancetre(X, X),
               setof(P, (ancetre(X, P), ancetre(P, X)), Membres) )).

% Un parent ne ou la meme annee que son enfant, ou plus tard.
incoherence(parent_plus_jeune, [P, E]) :-
    distinct([P, E], ( parent(P, E), naissance(P, NP), naissance(E, NE),
                       NP >= NE )).

% Un parent qui aurait eu son enfant avant l'age minimum.
incoherence(parent_trop_jeune, [P, E]) :-
    ecart_min_parent(Min),
    distinct([P, E], ( parent(P, E), naissance(P, NP), naissance(E, NE),
                       NP < NE, NE - NP < Min )).

% Plus de deux parents biologiques.
incoherence(trop_de_parents, [E|Parents]) :-
    distinct(E, parent(_, E)),
    setof(P, parent(P, E), Parents),
    length(Parents, N),
    N > 2.

% Une meme personne declaree homme et femme.
incoherence(sexe_contradictoire, [X]) :-
    distinct(X, ( personne(X, _, h, _, _), personne(X, _, f, _, _) )).

% Un deces avant la naissance.
incoherence(deces_avant_naissance, [X]) :-
    distinct(X, ( personne(X, _, _, N, D), integer(D), D < N )).

% Un enfant ne apres le deces de sa mere.
incoherence(naissance_apres_deces_mere, [M, E]) :-
    distinct([M, E], ( parent(M, E), femme(M), deces(M, DM),
                       naissance(E, NE), NE > DM )).

% Un enfant ne plus d'un an apres le deces de son pere.
incoherence(naissance_apres_deces_pere, [P, E]) :-
    distinct([P, E], ( parent(P, E), homme(P), deces(P, DP),
                       naissance(E, NE), NE > DP + 1 )).

% Une duree de vie impossible (vivant ou decede).
incoherence(longevite_impossible, [X]) :-
    longevite_max(Max),
    distinct(X, ( personne(X, _, _, N, D),
                  age(N, D, Age),
                  Age > Max )).

% Un mariage entre un ascendant et son descendant (parent-enfant, etc.).
% L'ascendant est place en premier dans la liste.
incoherence(mariage_ascendant, [A, D]) :-
    distinct([A, D], ( conjoint(X, Y),
                       (   ancetre(X, Y) -> A = X, D = Y
                       ;   ancetre(Y, X) -> A = Y, D = X
                       ) )).

% Un mariage entre frere et soeur (ou demi-frere et demi-soeur).
incoherence(mariage_fratrie, [X, Y]) :-
    distinct([X, Y], ( conjoint(X, Y), frere_ou_soeur(X, Y) )).

% Un lien qui cite un identifiant jamais declare par personne/5
% (utile quand des liens sont ajoutes depuis l'interface).
incoherence(reference_inconnue, [X]) :-
    distinct(X, ( ( parent(X, _) ; parent(_, X)
                  ; conjoint(X, _) ; conjoint(_, X) ),
                  \+ personne(X, _, _, _, _) )).

age(N, vivant, Age) :- !, annee_courante(A), Age is A - N.
age(N, D, Age)      :- integer(D), Age is D - N.


% =====================================================================
%  Messages lisibles : message(Code, Personnes, Texte)
% =====================================================================

message(cycle, Membres, T) :-
    maplist(nom, Membres, Noms),
    atomic_list_concat(Noms, ', ', Liste),
    format(atom(T), "Cycle de filiation : ~w sont chacun leur propre ancêtre.", [Liste]).
message(parent_plus_jeune, [P, E], T) :-
    nom(P, NP), nom(E, NE), naissance(P, AP), naissance(E, AE),
    format(atom(T), "~w (né(e) en ~w) est déclaré(e) parent de ~w (né(e) en ~w) : un parent ne peut pas être plus jeune que son enfant.",
           [NP, AP, NE, AE]).
message(parent_trop_jeune, [P, E], T) :-
    nom(P, NP), nom(E, NE), naissance(P, AP), naissance(E, AE),
    Age is AE - AP, ecart_min_parent(Min),
    format(atom(T), "~w aurait eu ~w à ~w ans (minimum attendu : ~w ans).",
           [NP, NE, Age, Min]).
message(trop_de_parents, [E|Ps], T) :-
    nom(E, NE), maplist(nom, Ps, Noms), length(Ps, N),
    atomic_list_concat(Noms, ', ', Liste),
    format(atom(T), "~w a ~w parents biologiques déclarés (~w) : deux au maximum.",
           [NE, N, Liste]).
message(sexe_contradictoire, [X], T) :-
    nom(X, N),
    format(atom(T), "~w est déclaré(e) à la fois homme et femme.", [N]).
message(deces_avant_naissance, [X], T) :-
    nom(X, N), personne(X, _, _, AN, AD), integer(AD), AD < AN, !,
    format(atom(T), "~w serait décédé(e) en ~w, avant sa naissance en ~w.", [N, AD, AN]).
message(naissance_apres_deces_mere, [M, E], T) :-
    nom(M, NM), nom(E, NE), deces(M, DM), naissance(E, AE),
    format(atom(T), "~w est né(e) en ~w, après le décès de sa mère ~w en ~w.",
           [NE, AE, NM, DM]).
message(naissance_apres_deces_pere, [P, E], T) :-
    nom(P, NP), nom(E, NE), deces(P, DP), naissance(E, AE),
    format(atom(T), "~w est né(e) en ~w, plus d'un an après le décès de son père ~w en ~w.",
           [NE, AE, NP, DP]).
message(longevite_impossible, [X], T) :-
    nom(X, N), personne(X, _, _, AN, AD), age(AN, AD, Age), !,
    format(atom(T), "~w (né(e) en ~w) aurait ~w ans : durée de vie impossible.", [N, AN, Age]).
message(mariage_ascendant, [A, D], T) :-
    nom(A, NA), nom(D, ND),
    format(atom(T), "~w et ~w sont mariés alors que ~w est un ascendant de ~w.",
           [NA, ND, NA, ND]).
message(mariage_fratrie, [X, Y], T) :-
    nom(X, NX), nom(Y, NY),
    format(atom(T), "~w et ~w sont mariés alors qu'ils sont frère et sœur.", [NX, NY]).
message(reference_inconnue, [X], T) :-
    format(atom(T), "L'identifiant ~w apparaît dans un lien mais n'est déclaré par aucune personne.", [X]).


% =====================================================================
%  Synthese pour l'interface
% =====================================================================

% alertes(L) : toutes les incoherences avec leur message.
alertes(L) :-
    findall(alerte(Code, Ps, Texte),
            ( incoherence(Code, Ps), once(message(Code, Ps, Texte)) ),
            L).

% personnes_en_erreur(L) : ids impliques dans au moins une incoherence.
personnes_en_erreur(L) :-
    (   setof(X, C^Ps^(incoherence(C, Ps), member(X, Ps)), L)
    ->  true
    ;   L = []
    ).

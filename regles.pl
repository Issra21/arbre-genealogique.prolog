% =====================================================================
%  regles.pl -- Regles de parente, 3 niveaux
%    Niveau 1 : parent, enfant, frere, soeur
%    Niveau 2 : grands-parents, oncles, tantes, cousins
%    Niveau 3 : ancetres, descendants, degre de cousinage, chemin de parente
%  Responsable : Issra
%
%  Convention : relation(X, Y) se lit "X est le/la <relation> de Y".
%    pere(maher, sami)  ->  Maher est le pere de Sami.
%    frere(sami, ines)  ->  Sami est le frere d'Ines.
%
%  Ce fichier ne contient aucun fait : il se charge avec un fichier
%  de donnees, par exemple :
%    swipl donnees/famille.pl regles.pl
% =====================================================================


% ---------------------------------------------------------------------
%  Utilitaires : sexe, mariage
% ---------------------------------------------------------------------

% nom(X, Nom) : nom affiche ; l'identifiant lui-meme si X est inconnu.
nom(X, Nom) :- personne(X, Nom, _, _, _), !.
nom(X, X).

homme(X) :- personne(X, _, h, _, _).
femme(X) :- personne(X, _, f, _, _).

% marie(X, Y) : X et Y sont maries. conjoint/2 n'est declare qu'une
% fois par couple dans les donnees ; on le rend symetrique ici.
marie(X, Y) :- conjoint(X, Y).
marie(X, Y) :- conjoint(Y, X).


% =====================================================================
%  NIVEAU 1 : parent, enfant, frere, soeur
% =====================================================================

% --- Ascendants directs ----------------------------------------------
% parent/2 est un fait : parent(P, E) = P est un parent de E.

pere(P, E) :- parent(P, E), homme(P).
mere(M, E) :- parent(M, E), femme(M).

% --- Descendants directs ---------------------------------------------

enfant(E, P) :- parent(P, E).
fils(E, P)   :- enfant(E, P), homme(E).
fille(E, P)  :- enfant(E, P), femme(E).

% --- Fratrie ---------------------------------------------------------
% frere_ou_soeur(X, Y) : X et Y ont au moins un parent en commun.
% distinct/2 evite de renvoyer deux fois la meme paire (une fois par
% parent partage).

frere_ou_soeur(X, Y) :-
    distinct(X-Y, ( parent(P, X), parent(P, Y), X \== Y )).

% germains(X, Y) : X et Y ont les deux memes parents.
germains(X, Y) :-
    distinct(X-Y, ( parent(P1, X), parent(P1, Y),
                    parent(P2, X), parent(P2, Y),
                    P1 @< P2, X \== Y )).

% demi_frere_ou_soeur(X, Y) : un seul parent en commun.
demi_frere_ou_soeur(X, Y) :-
    frere_ou_soeur(X, Y),
    \+ germains(X, Y).

frere(X, Y) :- frere_ou_soeur(X, Y), homme(X).
soeur(X, Y) :- frere_ou_soeur(X, Y), femme(X).


% =====================================================================
%  NIVEAU 2 : grands-parents, oncles, tantes, cousins
% =====================================================================

% --- Grands-parents / petits-enfants ---------------------------------

grand_parent(G, E) :-
    distinct(G-E, ( parent(G, P), parent(P, E) )).

grand_pere(G, E) :- grand_parent(G, E), homme(G).
grand_mere(G, E) :- grand_parent(G, E), femme(G).

petit_enfant(E, G) :- grand_parent(G, E).
petit_fils(E, G)   :- petit_enfant(E, G), homme(E).
petite_fille(E, G) :- petit_enfant(E, G), femme(E).

% --- Oncles et tantes ------------------------------------------------
% De sang : X est frere ou soeur d'un parent de Y.
oncle_tante_sang(X, Y) :-
    distinct(X-Y, ( parent(P, Y), frere_ou_soeur(X, P) )).

% Par alliance : X est marie(e) a un frere ou une soeur d'un parent de Y.
oncle_tante_alliance(X, Y) :-
    distinct(X-Y, ( parent(P, Y), frere_ou_soeur(S, P), marie(X, S),
                    \+ parent(X, Y),
                    \+ oncle_tante_sang(X, Y) )).

oncle_ou_tante(X, Y) :-
    distinct(X-Y, ( oncle_tante_sang(X, Y) ; oncle_tante_alliance(X, Y) )).

oncle(X, Y) :- oncle_ou_tante(X, Y), homme(X).
tante(X, Y) :- oncle_ou_tante(X, Y), femme(X).

% --- Neveux et nieces ------------------------------------------------

neveu_ou_niece(N, X) :- oncle_ou_tante(X, N).
neveu(N, X)          :- neveu_ou_niece(N, X), homme(N).
niece(N, X)          :- neveu_ou_niece(N, X), femme(N).

% --- Cousins germains ------------------------------------------------
% X et Y ont chacun un parent, et ces deux parents sont frere/soeur.

cousin_germain(X, Y) :-
    distinct(X-Y, ( parent(PX, X), parent(PY, Y),
                    frere_ou_soeur(PX, PY),
                    X \== Y,
                    \+ frere_ou_soeur(X, Y) )).

cousin(X, Y)   :- cousin_germain(X, Y), homme(X).
cousine(X, Y)  :- cousin_germain(X, Y), femme(X).


% =====================================================================
%  NIVEAU 3 : ancetres, descendants, degre de cousinage, chemin
% =====================================================================

% --- Ancetres / descendants ------------------------------------------
% ancetre(A, D) : A est un ancetre de D.
% Le tabling garantit la terminaison meme si les donnees contiennent un
% cycle (cas E1 de famille_erreurs.pl) : sans lui, la recursion bouclerait.

:- table ancetre/2.

ancetre(A, D) :- parent(A, D).
ancetre(A, D) :- parent(A, X), ancetre(X, D).

descendant(D, A) :- ancetre(A, D).

% ancetre(A, D, N) : A est un ancetre de D, N generations au-dessus
% (1 = parent, 2 = grand-parent, ...). La liste des personnes deja vues
% empeche de tourner en rond en cas de cycle.

ancetre(A, D, N) :- ascendant_(D, A, [D], N).

ascendant_(D, A, _, 1) :-
    parent(A, D).
ascendant_(D, A, Vus, N) :-
    parent(P, D),
    \+ memberchk(P, Vus),
    ascendant_(P, A, [P|Vus], N0),
    N is N0 + 1.

% ascendant_ou_soi(X, A, N) : comme ancetre/3, mais X est aussi son
% propre "ancetre" a 0 generation (utile quand Y descend de X).
ascendant_ou_soi(X, X, 0).
ascendant_ou_soi(X, A, N) :- ancetre(A, X, N).

% --- Ancetres communs les plus proches -------------------------------
% ancetres_communs_proches(X, Y, L) : L = liste des a(A, NX, NY) ou A est
% un ancetre commun de X et Y, a NX generations de X et NY de Y, avec
% NX + NY minimal. Il y en a souvent deux (le grand-pere et la grand-mere).

ancetres_communs_proches(X, Y, L) :-
    X \== Y,
    findall(S-a(A, NX, NY),
            ( ascendant_ou_soi(X, A, NX),
              ascendant_ou_soi(Y, A, NY),
              S is NX + NY ),
            Tous),
    Tous \== [],
    aggregate_all(min(S), member(S-_, Tous), Min),
    findall(T, member(Min-T, Tous), L0),
    sort(L0, L).

ancetre_commun_proche(X, Y, A, NX, NY) :-
    ancetres_communs_proches(X, Y, L),
    member(a(A, NX, NY), L).

% --- Degres -----------------------------------------------------------
% degre_civil(X, Y, D) : nombre de generations entre X et Y en passant
% par l'ancetre commun le plus proche (comptage du droit civil :
% parent = 1, frere = 2, oncle = 3, cousin germain = 4).

degre_civil(X, Y, D) :-
    once(ancetre_commun_proche(X, Y, _, NX, NY)),
    D is NX + NY.

% degre_cousinage(X, Y, Degre, Ecart) : X et Y sont cousins.
%   Degre = 1 pour des cousins germains, 2 pour des cousins issus de
%   germains, etc. Ecart = difference de generations (0 si meme generation).

degre_cousinage(X, Y, Degre, Ecart) :-
    once(ancetre_commun_proche(X, Y, _, NX, NY)),
    NX >= 2, NY >= 2,
    Degre is min(NX, NY) - 1,
    Ecart is abs(NX - NY).

% --- Chemin de parente ------------------------------------------------
% chemin(X, Y, Pas) : plus court chemin de X a Y dans l'arbre, en
% passant par les liens parent, enfant et conjoint (parcours en largeur).
% Pas = liste de pas(De, Lien, Vers), qui se lit "Vers est le <Lien> de De".
%   chemin(sami, amine, P) ->
%     P = [pas(sami, pere, maher), pas(maher, pere, habib),
%          pas(habib, fille, nadia), pas(nadia, fils, amine)]

chemin(X, Y, Pas) :-
    X \== Y,
    largeur([X-[]], [X], Y, PasInverse),
    reverse(PasInverse, Pas).

largeur([N-Acc|_], _, N, Acc) :- !.
largeur([N-Acc|Reste], Vus, Y, Res) :-
    findall(V-L, voisin(N, L, V), Candidats),
    nouveaux(Candidats, N, Acc, Vus, Nouveaux, Vus1),
    append(Reste, Nouveaux, File),
    largeur(File, Vus1, Y, Res).

nouveaux([], _, _, Vus, [], Vus).
nouveaux([V-L|T], N, Acc, Vus, Nouveaux, VusF) :-
    (   memberchk(V, Vus)
    ->  nouveaux(T, N, Acc, Vus, Nouveaux, VusF)
    ;   Nouveaux = [V-[pas(N, L, V)|Acc]|Suite],
        nouveaux(T, N, Acc, [V|Vus], Suite, VusF)
    ).

% voisin(N, Lien, V) : V est le <Lien> de N.
voisin(N, pere, V)   :- parent(V, N), homme(V).
voisin(N, mere, V)   :- parent(V, N), femme(V).
voisin(N, fils, V)   :- parent(N, V), homme(V).
voisin(N, fille, V)  :- parent(N, V), femme(V).
voisin(N, epoux, V)  :- marie(N, V), homme(V).
voisin(N, epouse, V) :- marie(N, V), femme(V).

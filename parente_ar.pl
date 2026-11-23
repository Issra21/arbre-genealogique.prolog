:- encoding(utf8).
% =====================================================================
%  parente_ar.pl -- Nom du lien de parente en francais et en arabe,
%  et mise en forme du chemin de parente
%  Responsable : Issra
%
%  Se charge apres les donnees et regles.pl.
%
%  Predicats utiles pour l'interface :
%    relation(X, Y, Code, Fr, Ar)   "X est le/la <Fr> de Y"
%    phrase_relation(X, Y, Fr, Ar)  phrase complete dans les deux langues
%    chemin_texte(X, Y, Texte)      "Sami → père : Maher → ..."
%    lien_pas(Lien, Fr, Ar)         traduction d'un pas du chemin
%
%  Termes arabes : arabe standard. L'arabe distingue le cote paternel
%  (عمّ / عمّة) du cote maternel (خال / خالة).
%  A VALIDER par Issra avant la demo (choix standard / tunisien).
% =====================================================================

sexe(X, S) :- personne(X, _, S, _, _), !.

% g(Sexe, Masculin, Feminin, Mot)
g(h, M, _, M).
g(f, _, F, F).


% =====================================================================
%  relation(X, Y, Code, Fr, Ar)
%  On cherche d'abord un lien de sang (ancetre commun), sinon un lien
%  par alliance (mariage), sinon "aucun lien".
% =====================================================================

relation(X, Y, Code, Fr, Ar) :-
    X \== Y,
    (   lien_sang(X, Y, Code, Fr, Ar)     -> true
    ;   lien_alliance(X, Y, Code, Fr, Ar) -> true
    ;   Code = aucun,
        Fr = 'aucun lien connu',
        Ar = 'لا توجد قرابة معروفة'
    ).

% --- Liens de sang ----------------------------------------------------
% NX = generations de X jusqu'a l'ancetre commun, NY = de Y jusqu'a lui.

lien_sang(X, Y, Code, Fr, Ar) :-
    once(ancetre_commun_proche(X, Y, _, NX, NY)),
    sexe(X, S),
    once(sang(NX, NY, X, Y, S, Code, Fr, Ar)).

% X est parent / grand-parent / arriere-grand-parent de Y
sang(0, 1, _, _, S, parent, Fr, Ar) :-
    g(S, 'père', 'mère', Fr), g(S, 'أب', 'أم', Ar).
sang(0, 2, _, _, S, grand_parent, Fr, Ar) :-
    g(S, 'grand-père', 'grand-mère', Fr), g(S, 'جد', 'جدة', Ar).
sang(0, N, _, _, S, arriere_grand_parent, Fr, Ar) :-
    N >= 3, K is N - 2, arrieres(K, Pref),
    g(S, 'grand-père', 'grand-mère', B), atom_concat(Pref, B, Fr),
    g(S, 'جد', 'جدة', A0), format(atom(Ar), '~w من الجيل ~w', [A0, N]).

% X est enfant / petit-enfant / arriere-petit-enfant de Y
sang(1, 0, _, _, S, enfant, Fr, Ar) :-
    g(S, 'fils', 'fille', Fr), g(S, 'ابن', 'بنت', Ar).
sang(2, 0, _, _, S, petit_enfant, Fr, Ar) :-
    g(S, 'petit-fils', 'petite-fille', Fr), g(S, 'حفيد', 'حفيدة', Ar).
sang(N, 0, _, _, S, arriere_petit_enfant, Fr, Ar) :-
    N >= 3, K is N - 2, arrieres(K, Pref),
    g(S, 'petit-fils', 'petite-fille', B), atom_concat(Pref, B, Fr),
    g(S, 'حفيد', 'حفيدة', A0), format(atom(Ar), '~w من الجيل ~w', [A0, N]).

% Frere / soeur
sang(1, 1, X, Y, S, Code, Fr, Ar) :-
    (   demi_frere_ou_soeur(X, Y)
    ->  Code = demi_frere_soeur,
        g(S, 'demi-frère', 'demi-sœur', Fr),
        g(S, 'أخ غير شقيق', 'أخت غير شقيقة', Ar)
    ;   Code = frere_soeur,
        g(S, 'frère', 'sœur', Fr),
        g(S, 'أخ', 'أخت', Ar)
    ).

% Oncle / tante : X est frere/soeur du parent P de Y.
% Le sexe de P donne le cote : pere -> paternel (عمّ), mere -> maternel (خال).
sang(1, 2, X, Y, S, oncle_tante, Fr, Ar) :-
    parent(P, Y), frere_ou_soeur(X, P), !,
    sexe(P, SP),
    g(S, 'oncle', 'tante', B), cote_fr(SP, S, Cote),
    atomic_list_concat([B, ' ', Cote], Fr),
    oncle_ar(SP, S, Ar).

% Grand-oncle / grand-tante : X est frere/soeur d'un grand-parent G de Y.
% En arabe : "عمّ الأم" = oncle paternel de la mere, etc.
sang(1, 3, X, Y, S, grand_oncle_tante, Fr, Ar) :-
    parent(P, Y), parent(G, P), frere_ou_soeur(X, G), !,
    g(S, 'grand-oncle', 'grand-tante', Fr),
    sexe(G, SG), oncle_ar(SG, S, A0),
    sexe(P, SP), g(SP, 'الأب', 'الأم', Suf),
    atomic_list_concat([A0, ' ', Suf], Ar).

% Neveu / niece : un parent PX de X est frere/soeur de Y.
sang(2, 1, X, Y, S, neveu_niece, Fr, Ar) :-
    parent(PX, X), frere_ou_soeur(PX, Y), !,
    g(S, 'neveu', 'nièce', Fr),
    g(S, 'ابن', 'بنت', B), sexe(PX, SPX), g(SPX, 'الأخ', 'الأخت', Suf),
    atomic_list_concat([B, ' ', Suf], Ar).

% Petit-neveu / petite-niece : un grand-parent de X est frere/soeur de Y.
sang(3, 1, X, Y, S, petit_neveu_niece, Fr, Ar) :-
    parent(PX, X), parent(GX, PX), frere_ou_soeur(GX, Y), !,
    g(S, 'petit-neveu', 'petite-nièce', Fr),
    g(S, 'حفيد', 'حفيدة', B), sexe(GX, SGX), g(SGX, 'الأخ', 'الأخت', Suf),
    atomic_list_concat([B, ' ', Suf], Ar).

% Cousin germain : les parents PX et PY sont frere/soeur.
% En arabe : "ابن العمّ" = fils de l'oncle paternel, "بنت الخالة" = fille
% de la tante maternelle, etc.
sang(2, 2, X, Y, S, cousin_germain, Fr, Ar) :-
    parent(PX, X), parent(PY, Y), frere_ou_soeur(PX, PY), !,
    g(S, 'cousin germain', 'cousine germaine', Fr),
    g(S, 'ابن', 'بنت', B), sexe(PY, SPY), sexe(PX, SPX),
    oncle_ar_def(SPY, SPX, O),
    atomic_list_concat([B, ' ', O], Ar).

% Cousins de meme generation, plus eloignes.
sang(N, N, _, _, S, cousin, Fr, Ar) :-
    N >= 3,
    (   N =:= 3
    ->  g(S, 'cousin issu de germain', 'cousine issue de germain', Fr)
    ;   Degre is N - 1, g(S, 'cousin', 'cousine', B),
        format(atom(Fr), '~w au ~we degré', [B, Degre])
    ),
    D is 2 * N, g(S, 'قريب', 'قريبة', A0),
    format(atom(Ar), '~w من الدرجة ~w', [A0, D]).

% Cousins de generations differentes.
sang(NX, NY, _, _, S, cousin_eloigne, Fr, Ar) :-
    NX >= 2, NY >= 2, NX =\= NY,
    E is abs(NX - NY),
    ( E =:= 1 -> Gen = 'génération' ; Gen = 'générations' ),
    g(S, 'cousin éloigné', 'cousine éloignée', B),
    format(atom(Fr), '~w (~w ~w d\'écart)', [B, E, Gen]),
    D is NX + NY, g(S, 'قريب', 'قريبة', A0),
    format(atom(Ar), '~w من الدرجة ~w', [A0, D]).

% Tout autre lien de sang : degre civil.
sang(NX, NY, _, _, S, parent_eloigne, Fr, Ar) :-
    D is NX + NY,
    g(S, 'parent', 'parente', B), format(atom(Fr), '~w au ~we degré', [B, D]),
    g(S, 'قريب', 'قريبة', A0), format(atom(Ar), '~w من الدرجة ~w', [A0, D]).

% --- Liens par alliance -------------------------------------------------

lien_alliance(X, Y, Code, Fr, Ar) :-
    sexe(X, S),
    once(alliance(X, Y, S, Code, Fr, Ar)).

% Epoux / epouse
alliance(X, Y, S, conjoint, Fr, Ar) :-
    marie(X, Y),
    g(S, 'époux', 'épouse', Fr), g(S, 'زوج', 'زوجة', Ar).
% Beau-pere / belle-mere : X est parent du conjoint de Y.
alliance(X, Y, S, beau_parent, Fr, Ar) :-
    marie(Y, C), parent(X, C),
    g(S, 'beau-père', 'belle-mère', Fr), g(S, 'حمو', 'حماة', Ar).
% Gendre / belle-fille : X est le conjoint d'un enfant de Y.
alliance(X, Y, S, gendre_belle_fille, Fr, Ar) :-
    parent(Y, E), marie(E, X),
    g(S, 'gendre', 'belle-fille', Fr), g(S, 'صهر', 'كنّة', Ar).
% Oncle / tante par alliance : X est marie(e) a un frere/soeur d'un parent
% de Y. En arabe : "زوج العمّة" = mari de la tante paternelle, etc.
alliance(X, Y, S, oncle_tante_alliance, Fr, Ar) :-
    parent(PY, Y), frere_ou_soeur(O, PY), marie(X, O),
    g(S, 'oncle par alliance', 'tante par alliance', Fr),
    g(S, 'زوج', 'زوجة', B), sexe(PY, SPY), sexe(O, SO),
    oncle_ar_def(SPY, SO, OA),
    atomic_list_concat([B, ' ', OA], Ar).
% Neveu / niece par alliance : un parent de X est frere/soeur du conjoint
% de Y. En arabe : "ابن أخ الزوجة" = fils du frere de l'epouse, etc.
alliance(X, Y, S, neveu_niece_alliance, Fr, Ar) :-
    parent(PX, X), frere_ou_soeur(PX, O), marie(O, Y),
    g(S, 'neveu par alliance', 'nièce par alliance', Fr),
    g(S, 'ابن', 'بنت', B), sexe(PX, SPX), g(SPX, 'أخ', 'أخت', Fratrie),
    sexe(Y, SY), g(SY, 'الزوجة', 'الزوج', Conj),
    atomic_list_concat([B, ' ', Fratrie, ' ', Conj], Ar).
% Beau-frere / belle-soeur : frere/soeur du conjoint, ou conjoint d'un
% frere/soeur.
alliance(X, Y, S, beau_frere_soeur, Fr, Ar) :-
    (   marie(Y, C), frere_ou_soeur(X, C)
    ;   frere_ou_soeur(F, Y), marie(F, X)
    ),
    g(S, 'beau-frère', 'belle-sœur', Fr), g(S, 'نسيب', 'نسيبة', Ar).
% Tout autre lien qui passe par un mariage.
alliance(X, Y, S, alliance, Fr, Ar) :-
    chemin(X, Y, _),
    g(S, 'parent par alliance', 'parente par alliance', Fr),
    g(S, 'نسيب', 'نسيبة', Ar).

% --- Vocabulaire ------------------------------------------------------

% arrieres(K, Prefixe) : "arrière-" repete K fois.
arrieres(K, Pref) :-
    length(L, K), maplist(=('arrière-'), L), atomic_list_concat(L, Pref).

% cote_fr(SexeDuParent, SexeDeX, Mot)
cote_fr(h, h, 'paternel').
cote_fr(h, f, 'paternelle').
cote_fr(f, h, 'maternel').
cote_fr(f, f, 'maternelle').

% oncle_ar(SexeDuParent, SexeDeX, Mot) : عمّ / عمّة (cote pere),
% خال / خالة (cote mere).
oncle_ar(h, S, Ar) :- g(S, 'عمّ', 'عمّة', Ar).
oncle_ar(f, S, Ar) :- g(S, 'خال', 'خالة', Ar).

% Meme chose avec l'article (pour "ابن العمّ", "زوجة الخال", ...).
oncle_ar_def(h, S, Ar) :- g(S, 'العمّ', 'العمّة', Ar).
oncle_ar_def(f, S, Ar) :- g(S, 'الخال', 'الخالة', Ar).


% =====================================================================
%  Phrases et chemin
% =====================================================================

% phrase_relation(X, Y, PhraseFr, PhraseAr)
%   "Nadia est la tante paternelle de Sami." / "Nadia هي عمّة Sami"
phrase_relation(X, Y, PFr, PAr) :-
    relation(X, Y, Code, Fr, Ar),
    nom(X, NX), nom(Y, NY),
    (   Code == aucun
    ->  format(atom(PFr), 'Aucun lien de parenté connu entre ~w et ~w.', [NX, NY]),
        format(atom(PAr), 'لا توجد قرابة معروفة بين ~w و ~w', [NX, NY])
    ;   ( sexe(X, S) -> true ; S = h ),
        article(Fr, S, Art), de(NY, DeNY),
        format(atom(PFr), '~w est ~w~w ~w.', [NX, Art, Fr, DeNY]),
        g(S, 'هو', 'هي', Pron),
        format(atom(PAr), '~w ~w ~w ~w', [NX, Pron, Ar, NY])
    ).

% article(Mot, Sexe, Article) : "l'" devant une voyelle, sinon "le "/"la ".
article(Mot, _, 'l\'') :- commence_par_voyelle(Mot), !.
article(_, h, 'le ').
article(_, f, 'la ').

% de(Nom, Texte) : "d'Ines", "de Sami".
de(Nom, T) :-
    (   commence_par_voyelle(Nom)
    ->  atom_concat('d\'', Nom, T)
    ;   atom_concat('de ', Nom, T)
    ).

commence_par_voyelle(Mot) :-
    sub_atom(Mot, 0, 1, _, C),
    memberchk(C, [a, e, i, o, u, y, 'é', 'è', 'ê', 'à', 'â', 'î', 'ô', 'û',
                  'A', 'E', 'I', 'O', 'U', 'Y', 'É']).

% lien_pas(Lien, Fr, Ar) : traduction des liens utilises par chemin/3.
lien_pas(pere,   'père',   'أب').
lien_pas(mere,   'mère',   'أم').
lien_pas(fils,   'fils',   'ابن').
lien_pas(fille,  'fille',  'بنت').
lien_pas(epoux,  'époux',  'زوج').
lien_pas(epouse, 'épouse', 'زوجة').

% chemin_texte(X, Y, Texte) :
%   "Sami → père : Maher → père : Habib → fille : Nadia → fils : Amine"
chemin_texte(X, Y, Texte) :-
    chemin(X, Y, Pas),
    nom(X, NX),
    maplist(etape_texte, Pas, Etapes),
    atomic_list_concat([NX|Etapes], ' → ', Texte).

etape_texte(pas(_, Lien, V), T) :-
    lien_pas(Lien, Fr, _), nom(V, NV),
    format(atom(T), '~w : ~w', [Fr, NV]).

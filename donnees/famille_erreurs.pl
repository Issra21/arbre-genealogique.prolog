% =====================================================================
%  donnees/famille_erreurs.pl -- Donnees VOLONTAIREMENT incoherentes
%  Sert a tester coherence.pl et a la demo.
%  Meme format que famille.pl. Chaque erreur utilise ses propres
%  personnes, pour que chaque alerte soit facile a attribuer.
%
%  Erreurs attendues :
%    E1  cycle : une personne est son propre ancetre (x1 -> x2 -> x3 -> x1)
%    E2  parent plus jeune que son enfant (p2 ne en 1990, e2 en 1980)
%    E3  parent ne moins de 12 ans avant l'enfant (p3 1980, e3 1988)
%    E4  plus de deux parents biologiques (e4 a trois parents)
%    E5  deux sexes declares pour la meme personne (s5)
%    E6  deces avant la naissance (d6 ne 1990, decede 1980)
%    E7  enfant ne apres le deces de sa mere (m7 decedee 1990, e7 ne 1995)
%    E8  mariage parent-enfant (p8 et e8)
%    E9  mariage frere-soeur (f9 et s9, memes parents)
%    E10 duree de vie impossible (v10 ne en 1880, toujours vivant)
%    E11 lien vers un identifiant non declare (z11, parent de e11)
% =====================================================================

% --- Personnes --------------------------------------------------------

% E1 : cycle
personne(x1, 'Ali',     h, 1950, vivant).
personne(x2, 'Bechir',  h, 1975, vivant).
personne(x3, 'Chokri',  h, 2000, vivant).

% E2 : parent plus jeune que l'enfant
personne(p2, 'Fethi',   h, 1990, vivant).
personne(e2, 'Ghazi',   h, 1980, vivant).

% E3 : parent ne moins de 12 ans avant l'enfant
personne(p3, 'Hamdi',   h, 1980, vivant).
personne(e3, 'Imed',    h, 1988, vivant).

% E4 : trois parents biologiques
personne(a4, 'Jamel',   h, 1950, vivant).
personne(b4, 'Khadija', f, 1952, vivant).
personne(c4, 'Lotfi',   h, 1951, vivant).
personne(e4, 'Mehdi',   h, 1980, vivant).

% E5 : deux sexes pour la meme personne (deux faits contradictoires)
personne(s5, 'Nour',    h, 1990, vivant).
personne(s5, 'Nour',    f, 1990, vivant).

% E6 : deces avant la naissance
personne(d6, 'Omar',    h, 1990, 1980).

% E7 : enfant ne apres le deces de sa mere
personne(m7, 'Rania',   f, 1960, 1990).
personne(e7, 'Selim',   h, 1995, vivant).

% E8 : mariage parent-enfant
personne(p8, 'Tarek',   h, 1950, vivant).
personne(e8, 'Wafa',    f, 1975, vivant).

% E9 : mariage frere-soeur
personne(pa9, 'Zied',   h, 1945, vivant).
personne(ma9, 'Amel',   f, 1948, vivant).
personne(f9,  'Bilel',  h, 1970, vivant).
personne(s9,  'Dorra',  f, 1972, vivant).

% E10 : duree de vie impossible
personne(v10, 'Hedi',   h, 1880, vivant).

% E11 : parent jamais declare (z11 n'a pas de fait personne/5)
personne(e11, 'Karima', f, 1990, vivant).

% --- Liens de filiation : parent(Parent, Enfant) ----------------------

parent(x1, x2).   parent(x2, x3).   parent(x3, x1).     % E1
parent(p2, e2).                                         % E2
parent(p3, e3).                                         % E3
parent(a4, e4).   parent(b4, e4).   parent(c4, e4).     % E4
parent(m7, e7).                                         % E7
parent(p8, e8).                                         % E8
parent(pa9, f9).  parent(ma9, f9).                      % E9
parent(pa9, s9).  parent(ma9, s9).                      % E9
parent(z11, e11).                                       % E11

% --- Mariages : conjoint(X, Y) ----------------------------------------

conjoint(p8, e8).                                       % E8
conjoint(f9, s9).                                       % E9

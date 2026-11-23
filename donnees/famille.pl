% =====================================================================
%  donnees/famille.pl -- Famille de test (donnees coherentes)
%  23 personnes sur 4 generations.
%
%  Format des faits :
%    personne(Id, Nom, Sexe, AnneeNaissance, AnneeDeces).
%        Sexe       : h (homme) | f (femme)
%        AnneeDeces : annee du deces, ou l'atome vivant
%    parent(Parent, Enfant).      % lien biologique
%    conjoint(X, Y).              % mariage, declare une seule fois
%                                 % (la symetrie est geree dans les regles)
%
%  Cas couverts pour tester les regles :
%    - grands-parents paternels ET maternels (Sami, Ines)
%    - oncles/tantes de sang : Nadia, Kamel (cote pere), Faouzi (cote mere)
%    - oncle/tante par alliance : Rached, Samia, Hela
%    - cousins germains : Sami/Amine, Sami/Youssef, Sami/Mariem
%    - cousins issus de germains (niveau 3) : Adam/Yassine, Lina/Yassine
%    - arriere-grands-parents : Habib, Zohra, Mokhtar, Aicha -> Adam, Lina
%    - personnes decedees : Habib, Zohra, Mokhtar, Maher
% =====================================================================

% --- Personnes --------------------------------------------------------

% Generation 1
personne(habib,   'Habib',   h, 1930, 2005).
personne(zohra,   'Zohra',   f, 1934, 2012).
personne(mokhtar, 'Mokhtar', h, 1932, 2010).
personne(aicha,   'Aicha',   f, 1936, vivant).

% Generation 2 (enfants + conjoints)
personne(maher,   'Maher',   h, 1955, 2015).
personne(nadia,   'Nadia',   f, 1958, vivant).
personne(kamel,   'Kamel',   h, 1962, vivant).
personne(leila,   'Leila',   f, 1957, vivant).
personne(faouzi,  'Faouzi',  h, 1960, vivant).
personne(rached,  'Rached',  h, 1954, vivant).
personne(samia,   'Samia',   f, 1965, vivant).
personne(hela,    'Hela',    f, 1963, vivant).

% Generation 3 (enfants + conjoints)
personne(sami,    'Sami',    h, 1982, vivant).
personne(ines,    'Ines',    f, 1985, vivant).
personne(amine,   'Amine',   h, 1983, vivant).
personne(rim,     'Rim',     f, 1988, vivant).
personne(youssef, 'Youssef', h, 1990, vivant).
personne(mariem,  'Mariem',  f, 1987, vivant).
personne(olfa,    'Olfa',    f, 1984, vivant).
personne(sarra,   'Sarra',   f, 1986, vivant).

% Generation 4
personne(adam,    'Adam',    h, 2010, vivant).
personne(lina,    'Lina',    f, 2014, vivant).
personne(yassine, 'Yassine', h, 2012, vivant).

% --- Liens de filiation : parent(Parent, Enfant) ----------------------

% Habib + Zohra -> Maher, Nadia, Kamel
parent(habib, maher).   parent(zohra, maher).
parent(habib, nadia).   parent(zohra, nadia).
parent(habib, kamel).   parent(zohra, kamel).

% Mokhtar + Aicha -> Leila, Faouzi
parent(mokhtar, leila). parent(aicha, leila).
parent(mokhtar, faouzi). parent(aicha, faouzi).

% Maher + Leila -> Sami, Ines
parent(maher, sami).    parent(leila, sami).
parent(maher, ines).    parent(leila, ines).

% Nadia + Rached -> Amine, Rim
parent(nadia, amine).   parent(rached, amine).
parent(nadia, rim).     parent(rached, rim).

% Kamel + Samia -> Youssef
parent(kamel, youssef). parent(samia, youssef).

% Faouzi + Hela -> Mariem
parent(faouzi, mariem). parent(hela, mariem).

% Sami + Olfa -> Adam, Lina
parent(sami, adam).     parent(olfa, adam).
parent(sami, lina).     parent(olfa, lina).

% Amine + Sarra -> Yassine
parent(amine, yassine). parent(sarra, yassine).

% --- Mariages : conjoint(X, Y) ----------------------------------------

conjoint(habib,   zohra).
conjoint(mokhtar, aicha).
conjoint(maher,   leila).
conjoint(rached,  nadia).
conjoint(kamel,   samia).
conjoint(faouzi,  hela).
conjoint(sami,    olfa).
conjoint(amine,   sarra).

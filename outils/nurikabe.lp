% Regles du Nurikabe en ASP (clingo). Faits attendus : #const n. clue(R,C,V).
cell(R,C) :- R = 1..n, C = 1..n.
adj(R,C,R+1,C) :- cell(R,C), cell(R+1,C).
adj(R,C,R-1,C) :- cell(R,C), cell(R-1,C).
adj(R,C,R,C+1) :- cell(R,C), cell(R,C+1).
adj(R,C,R,C-1) :- cell(R,C), cell(R,C-1).

{ black(R,C) } :- cell(R,C), not clue(R,C,_).
white(R,C) :- cell(R,C), not black(R,C).

% iles : chaque case blanche appartient a exactement un indice, taille exacte
own(R,C,R,C) :- clue(R,C,_).
own(X,Y,A,B) :- own(R,C,A,B), adj(R,C,X,Y), white(X,Y).
owned(R,C) :- own(R,C,_,_).
:- white(R,C), not owned(R,C).
:- own(R,C,A,B), own(R,C,A2,B2), (A,B) < (A2,B2).
:- clue(A,B,V), not V #count{ R,C : own(R,C,A,B) } V.

% pas de bassin 2x2
:- black(R,C), black(R+1,C), black(R,C+1), black(R+1,C+1).

% mer connexe : tout se rattache a la premiere case noire
lin(R,C,(R-1)*n+C) :- cell(R,C).
seen(I) :- lin(R,C,I), black(R,C).
seen(I+1) :- seen(I), I < n*n.
root(R,C) :- lin(R,C,I), black(R,C), not seen(I-1).
reach(R,C) :- root(R,C).
reach(X,Y) :- reach(R,C), adj(R,C,X,Y), black(X,Y).
:- black(R,C), not reach(R,C).
:- not seen(n*n).

#show black/2.

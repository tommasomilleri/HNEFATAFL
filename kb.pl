
% Rappresentazione dello stato e regole spaziali base

:- module(kb, [dimensione/1, trono/2, stato_iniziale/1]).

% Dimensione della griglia
dimensione(9).

% Posizione speciale: Il Trono
trono(5, 5).

% stato_iniziale(-ListaPezzi)
% Struttura: pezzo(Tipo, Fazione, X, Y)
stato_iniziale([
    % -- RE --
    pezzo(re, difensore, 5, 5),

    % -- DIFENSORI (Croce centrale) --
    pezzo(soldato, difensore, 5, 4), pezzo(soldato, difensore, 5, 6),
    pezzo(soldato, difensore, 4, 5), pezzo(soldato, difensore, 6, 5),
    pezzo(soldato, difensore, 5, 3), pezzo(soldato, difensore, 5, 7),
    pezzo(soldato, difensore, 3, 5), pezzo(soldato, difensore, 7, 5),

    % -- ATTACCANTI (4 gruppi a T sui bordi) --
    pezzo(soldato, attaccante, 4, 1), pezzo(soldato, attaccante, 5, 1), pezzo(soldato, attaccante, 6, 1), pezzo(soldato, attaccante, 5, 2),
    pezzo(soldato, attaccante, 4, 9), pezzo(soldato, attaccante, 5, 9), pezzo(soldato, attaccante, 6, 9), pezzo(soldato, attaccante, 5, 8),
    pezzo(soldato, attaccante, 1, 4), pezzo(soldato, attaccante, 1, 5), pezzo(soldato, attaccante, 1, 6), pezzo(soldato, attaccante, 2, 5),
    pezzo(soldato, attaccante, 9, 4), pezzo(soldato, attaccante, 9, 5), pezzo(soldato, attaccante, 9, 6), pezzo(soldato, attaccante, 8, 5)
]).
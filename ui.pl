% =========================================================
% MODULO: ui.pl (AGGIORNATO CON CURSORE INTERATTIVO)
% =========================================================

:- module(ui, [mostra_scacchiera/5]).
:- use_module(kb).

simbolo(re,          "\e[1;33m ♔ "). % Giallo
simbolo(difensore,   "\e[1;37m ♙ "). % Bianco
simbolo(attaccante,  "\e[1;31m ⚔ "). % Rosso
simbolo(trono,       "\e[1;32m ☒ "). % Verde
simbolo(vuoto,       " . ").

% Mostra Scacchiera ora prende anche la posizione del cursore e della selezione
mostra_scacchiera(Pezzi, CX, CY, SelX, SelY) :-
    write('\e[2J\e[H'), % Trucco da pro: pulisce istantaneamente il terminale
    nl, writeln('      1   2   3   4   5   6   7   8   9'),
    writeln('    +---+---+---+---+---+---+---+---+---+'),
    dimensione(N),
    forall(between(1, N, Y), (
        write(Y), write('   |'),
        forall(between(1, N, X), (
            stampa_cella(X, Y, Pezzi, CX, CY, SelX, SelY),
            write('\e[0m|') % Resetta i colori e chiude la cella
        )),
        nl, writeln('    +---+---+---+---+---+---+---+---+---+')
    )), nl,
    stampa_messaggi(SelX, SelY).

% Logica di Stampa (Con sfondi colorati)
stampa_cella(X, Y, Pezzi, CX, CY, SelX, SelY) :-
    % 1. Colore di sfondo (Cursore o Selezione)
    (   X == SelX, Y == SelY -> write("\e[42m") ; % Sfondo Verde: Selezionato
        X == CX, Y == CY     -> write("\e[44m") ; % Sfondo Blu: Cursore
        write("\e[0m") ),                         % Nessuno sfondo
    
    % 2. Stampa il pezzo
    (   member(pezzo(re, _, X, Y), Pezzi)         -> simbolo(re, S), write(S)
    ;   member(pezzo(_, difensore, X, Y), Pezzi)  -> simbolo(difensore, S), write(S)
    ;   member(pezzo(_, attaccante, X, Y), Pezzi) -> simbolo(attaccante, S), write(S)
    ;   trono(X, Y)                               -> simbolo(trono, S), write(S)
    ;   simbolo(vuoto, S), write(S)
    ).

% Messaggi di aiuto dinamici
stampa_messaggi(0, 0) :- writeln('Usa W, A, S, D per muovere il cursore. SPAZIO per selezionare. Q per uscire.').
stampa_messaggi(_, _) :- writeln('\e[1;32mPezzo selezionato!\e[0m Muovi il cursore e premi SPAZIO per spostarlo.').
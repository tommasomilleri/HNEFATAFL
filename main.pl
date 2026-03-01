% =========================================================
% MODULO: main.pl
% Scopo: Game Loop e Input Tastiera (WASD)
% =========================================================

:- use_module(kb).
:- use_module(ui).
:- use_module(engine).
:- use_module(library(lists)). % Necessario per spostare gli elementi nelle liste

% Punto di avvio del gioco
start :-
    kb:stato_iniziale(Pezzi),
    % loop(Pezzi, CursoreX, CursoreY, SelezionatoX, SelezionatoY)
    % Si inizia con il cursore al centro (5,5) e nessuna selezione (0,0)
    loop(Pezzi, 5, 5, 0, 0).

% Il loop infinito del gioco
loop(Pezzi, CX, CY, SelX, SelY) :-
    ui:mostra_scacchiera(Pezzi, CX, CY, SelX, SelY),
    get_single_char(Codice), % Mette in pausa e aspetta un tasto invisibile
    interpreta_tasto(Codice, Azione),
    esegui_azione(Azione, Pezzi, CX, CY, SelX, SelY).

% --- MAPPATURA TASTI (Supporta maiuscole e minuscole) ---
interpreta_tasto(119, nord). interpreta_tasto(87, nord). % W
interpreta_tasto(115, sud).  interpreta_tasto(83, sud).  % S
interpreta_tasto(97, ovest). interpreta_tasto(65, ovest).% A
interpreta_tasto(100, est).  interpreta_tasto(68, est).  % D
interpreta_tasto(32, seleziona).                         % SPAZIO
interpreta_tasto(113, esci). interpreta_tasto(81, esci). % Q
interpreta_tasto(_, ignora).                             % Qualsiasi altro tasto

% --- ESECUZIONE AZIONI ---

% 1. Uscita dal gioco
esegui_azione(esci, _, _, _, _, _) :- 
    write('\e[2J\e[H'), writeln('Uscita dal gioco. Arrivederci!'), !.

% 2. Movimento del cursore (WASD)
esegui_azione(Direzione, Pezzi, CX, CY, SelX, SelY) :-
    member(Direzione, [nord, sud, est, ovest]),
    muovi_cursore(Direzione, CX, CY, NewCX, NewCY),
    loop(Pezzi, NewCX, NewCY, SelX, SelY).

% 3. Premi SPAZIO: Selezione di un pezzo (Se non avevi selezionato nulla)
esegui_azione(seleziona, Pezzi, CX, CY, 0, 0) :-
    member(pezzo(_, _, CX, CY), Pezzi), !, % Se c'è un pezzo qui
    loop(Pezzi, CX, CY, CX, CY).           % Salva le coordinate come "Selezionato"

% Premi SPAZIO: Su casella vuota (Ignora)
esegui_azione(seleziona, Pezzi, CX, CY, 0, 0) :-
    !, loop(Pezzi, CX, CY, 0, 0).

% 4. Premi SPAZIO: Conferma Spostamento (Avevi già un pezzo selezionato)
esegui_azione(seleziona, Pezzi, CX, CY, SelX, SelY) :-
    SelX \= 0, SelY \= 0,
    (   CX == SelX, CY == SelY -> % Se premi spazio sullo STESSO pezzo, lo deseleziona
        loop(Pezzi, CX, CY, 0, 0)
    ;   engine:mossa_legale(SelX, SelY, CX, CY, Pezzi) -> % CHIEDE ALL'ENGINE SE LA MOSSA E' VALIDA
        aggiorna_pezzi(SelX, SelY, CX, CY, Pezzi, NuoviPezzi),
        loop(NuoviPezzi, CX, CY, 0, 0)
    ;   % Mossa illegale: fai un BEEP e annulla la selezione
        write('\a'), 
        loop(Pezzi, CX, CY, 0, 0)
    ).

% Ignora tasti sbagliati
esegui_azione(ignora, Pezzi, CX, CY, SelX, SelY) :-
    loop(Pezzi, CX, CY, SelX, SelY).

% --- LOGICA MATEMATICA DEL CURSORE ---
% max(1, ...) e min(9, ...) impediscono al cursore di uscire dalla scacchiera 9x9
muovi_cursore(nord, X, Y, X, NewY)  :- NewY is max(1, Y - 1).
muovi_cursore(sud,  X, Y, X, NewY)  :- NewY is min(9, Y + 1).
muovi_cursore(ovest,X, Y, NewX, Y)  :- NewX is max(1, X - 1).
muovi_cursore(est,  X, Y, NewX, Y)  :- NewX is min(9, X + 1).

% aggiorna_pezzi: Rimuove il vecchio pezzo e ne inserisce uno nuovo con le nuove coordinate
aggiorna_pezzi(X0, Y0, X1, Y1, Pezzi, NuoviPezzi) :-
    select(pezzo(Tipo, Fazione, X0, Y0), Pezzi, RestoPezzi),
    NuoviPezzi = [pezzo(Tipo, Fazione, X1, Y1) | RestoPezzi].
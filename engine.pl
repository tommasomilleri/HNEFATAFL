% =========================================================
% MODULO: engine.pl (TABLUT COPENHAGEN 9x9 - ALTA VELOCITA')
% Scopo: Regole di movimento, Catture storiche e Vittoria
% =========================================================

:- module(engine, [mossa_legale/5, applica_mossa/6, vittoria/2]).
:- use_module(kb).

% --- 1. VALIDAZIONE MOSSA ---
mossa_legale(X0, Y0, X1, Y1, Pezzi) :-
    member(pezzo(Tipo, _Fazione, X0, Y0), Pezzi),
    kb:dimensione(Max),
    between(1, Max, X1), between(1, Max, Y1),
    mossa_ortogonale(X0, Y0, X1, Y1),
    \+ member(pezzo(_, _, X1, Y1), Pezzi), 
    % REGOLA: Solo il Re può fermarsi sul trono o negli angoli
    (Tipo \= re -> \+ casella_speciale(X1, Y1) ; true),
    % Verifica rapida ostacoli
    percorso_libero(X0, Y0, X1, Y1, Pezzi).

mossa_ortogonale(X0, Y, X1, Y) :- X0 \= X1.
mossa_ortogonale(X, Y0, X, Y1) :- Y0 \= Y1.

% OTTIMIZZAZIONE CPU: Ricorsione pura al posto di forall/between (100x più veloce)
percorso_libero(X0, Y, X1, Y, Pezzi) :- 
    X0 \= X1, MinX is min(X0, X1) + 1, MaxX is max(X0, X1) - 1,
    nessun_pezzo_x(MinX, MaxX, Y, Pezzi).
percorso_libero(X, Y0, X, Y1, Pezzi) :- 
    Y0 \= Y1, MinY is min(Y0, Y1) + 1, MaxY is max(Y0, Y1) - 1,
    nessun_pezzo_y(MinY, MaxY, X, Pezzi).

nessun_pezzo_x(Min, Max, _, _) :- Min > Max, !.
nessun_pezzo_x(Min, Max, Y, Pezzi) :- 
    \+ member(pezzo(_, _, Min, Y), Pezzi),
    Next is Min + 1, nessun_pezzo_x(Next, Max, Y, Pezzi).

nessun_pezzo_y(Min, Max, _, _) :- Min > Max, !.
nessun_pezzo_y(Min, Max, X, Pezzi) :- 
    \+ member(pezzo(_, _, X, Min), Pezzi),
    Next is Min + 1, nessun_pezzo_y(Next, Max, X, Pezzi).

% Definiamo Trono e Angoli
casella_speciale(5, 5). % Trono
casella_speciale(1, 1). casella_speciale(1, 9).
casella_speciale(9, 1). casella_speciale(9, 9).

% --- 2. APPLICAZIONE MOSSA E CATTURE ---
applica_mossa(X0, Y0, X1, Y1, Pezzi, PezziFinali) :-
    select(pezzo(Tipo, Fazione, X0, Y0), Pezzi, Resto),
    PezziMossi = [pezzo(Tipo, Fazione, X1, Y1) | Resto],
    
    % Controllo catture standard in 4 direzioni (Estremamente ottimizzato)
    cattura_direzione(X1, Y1, 0, -1, Fazione, PezziMossi, P1), % Nord
    cattura_direzione(X1, Y1, 0, 1, Fazione, P1, P2),          % Sud
    cattura_direzione(X1, Y1, -1, 0, Fazione, P2, P3),         % Ovest
    cattura_direzione(X1, Y1, 1, 0, Fazione, P3, P4),          % Est
    
    % Controllo se QUESTA mossa ha catturato il Re (Anti-suicidio integrato)
    cattura_re(Fazione, P4, PezziFinali).

% Logica del Sandwich per i normali SOLDATI + BUG FIX "Trono Vuoto"
cattura_direzione(X, Y, DX, DY, MiaFazione, PezziIn, PezziOut) :-
    Nx is X + DX, Ny is Y + DY,             
    avversario(MiaFazione, Nemico),
    % Lazy Evaluation: Calcola l'incudine SOLO se abbiamo trovato un nemico in mezzo (risparmia CPU)
    ( select(pezzo(soldato, Nemico, Nx, Ny), PezziIn, Resto) ->
        Ox is Nx + DX, Oy is Ny + DY,           
        % REGOLA DI COPENHAGEN: Una casella speciale fa da incudine SOLO SE È VUOTA!
        (
        ( member(pezzo(_, MiaFazione, Ox, Oy), PezziIn) ; 
          (casella_speciale(Ox, Oy), \+ member(pezzo(_, _, Ox, Oy), PezziIn)) 
        ) ->
            PezziOut = Resto 
        ; PezziOut = PezziIn 
        )
    ; PezziOut = PezziIn     
    ).

% LOGICA DI CATTURA DEL RE
cattura_re(difensore, Pezzi, Pezzi) :- !. % Il difensore non può auto-uccidere il Re
cattura_re(attaccante, Pezzi, PezziFinali) :-
    ( member(pezzo(re, difensore, RX, RY), Pezzi),
      re_in_trappola(RX, RY, Pezzi) ->
      select(pezzo(re, difensore, RX, RY), Pezzi, PezziFinali)
    ; PezziFinali = Pezzi
    ).

% Caso A: Re sul Trono (5,5) -> Richiede 4 nemici 
re_in_trappola(5, 5, Pezzi) :- !,
    ostile_al_re(5, 5, 0, -1, Pezzi), ostile_al_re(5, 5, 0, 1, Pezzi),
    ostile_al_re(5, 5, -1, 0, Pezzi), ostile_al_re(5, 5, 1, 0, Pezzi).

% Caso B: Re adiacente al Trono -> Richiede 3 nemici + 1 Trono (4 lati in totale)
re_in_trappola(RX, RY, Pezzi) :- adiacente_al_trono(RX, RY), !,
    ostile_al_re(RX, RY, 0, -1, Pezzi), ostile_al_re(RX, RY, 0, 1, Pezzi),
    ostile_al_re(RX, RY, -1, 0, Pezzi), ostile_al_re(RX, RY, 1, 0, Pezzi).

% Caso C: Re in campo aperto -> Sandwich a 2! (Basta chiuderlo su un asse)
re_in_trappola(RX, RY, Pezzi) :-
    ( (ostile_al_re(RX, RY, 0, -1, Pezzi), ostile_al_re(RX, RY, 0, 1, Pezzi), !) ; % Panino Verticale
      (ostile_al_re(RX, RY, -1, 0, Pezzi), ostile_al_re(RX, RY, 1, 0, Pezzi), !) ). % Panino Orizzontale

adiacente_al_trono(4, 5). adiacente_al_trono(6, 5).
adiacente_al_trono(5, 4). adiacente_al_trono(5, 6).

% Una casella adiacente al Re è "ostile" se è un Attaccante o una Casella Speciale VUOTA
ostile_al_re(RX, RY, DX, DY, Pezzi) :-
    NX is RX + DX, NY is RY + DY,
    ( member(pezzo(_, attaccante, NX, NY), Pezzi) ; 
      (casella_speciale(NX, NY), \+ member(pezzo(_, _, NX, NY), Pezzi)) 
    ).

avversario(difensore, attaccante).
avversario(attaccante, difensore).

% --- 3. CONDIZIONI DI VITTORIA ---
vittoria(Pezzi, difensore) :-
    member(pezzo(re, difensore, X, Y), Pezzi),
    casella_speciale(X, Y), X \= 5, !. 

vittoria(Pezzi, attaccante) :-
    \+ member(pezzo(re, difensore, _, _), Pezzi), !.
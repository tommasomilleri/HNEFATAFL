% =========================================================
% MODULO: engine.pl (TABLUT STORICO 9x9)
% Scopo: Regole di movimento, Catture storiche e Vittoria
% =========================================================

:- module(engine, [mossa_legale/5, applica_mossa/6, vittoria/2]).
:- use_module(kb).

% --- 1. VALIDAZIONE MOSSA ---
% Verifica se lo spostamento da (X0,Y0) a (X1,Y1) rispetta la fisica del gioco
mossa_legale(X0, Y0, X1, Y1, Pezzi) :-
    member(pezzo(Tipo, _Fazione, X0, Y0), Pezzi),
    mossa_ortogonale(X0, Y0, X1, Y1),
    kb:dimensione(Max),
    between(1, Max, X1), between(1, Max, Y1),
    \+ member(pezzo(_, _, X1, Y1), Pezzi), % La destinazione deve essere vuota
    percorso_libero(X0, Y0, X1, Y1, Pezzi), % Non può scavalcare altri pezzi
    % REGOLA: Solo il Re può fermarsi sul trono o negli angoli
    (Tipo \= re -> \+ casella_speciale(X1, Y1) ; true).

mossa_ortogonale(X0, Y, X1, Y) :- X0 \= X1.
mossa_ortogonale(X, Y0, X, Y1) :- Y0 \= Y1.

percorso_libero(X0, Y, X1, Y, Pezzi) :- 
    X0 \= X1, MinX is min(X0, X1) + 1, MaxX is max(X0, X1) - 1,
    forall(between(MinX, MaxX, X_Int), \+ member(pezzo(_, _, X_Int, Y), Pezzi)).
percorso_libero(X, Y0, X, Y1, Pezzi) :- 
    Y0 \= Y1, MinY is min(Y0, Y1) + 1, MaxY is max(Y0, Y1) - 1,
    forall(between(MinY, MaxY, Y_Int), \+ member(pezzo(_, _, X, Y_Int), Pezzi)).

% Definiamo Trono e Angoli
casella_speciale(5, 5). % Trono
casella_speciale(1, 1). casella_speciale(1, 9).
casella_speciale(9, 1). casella_speciale(9, 9).

% --- 2. APPLICAZIONE MOSSA E CATTURE ---
applica_mossa(X0, Y0, X1, Y1, Pezzi, PezziFinali) :-
    select(pezzo(Tipo, Fazione, X0, Y0), Pezzi, Resto),
    PezziMossi = [pezzo(Tipo, Fazione, X1, Y1) | Resto],
    
    % 1. Controllo le catture standard dei soldati (Sandwich a croce)
    cattura_direzione(X1, Y1, 0, -1, Fazione, PezziMossi, P1), % Nord
    cattura_direzione(X1, Y1, 0, 1, Fazione, P1, P2),          % Sud
    cattura_direzione(X1, Y1, -1, 0, Fazione, P2, P3),         % Ovest
    cattura_direzione(X1, Y1, 1, 0, Fazione, P3, P4),          % Est
    
    % 2. Controllo se QUESTA mossa ha catturato il Re
    % Passo la "Fazione" per evitare che il Re si suicidi muovendosi tra due nemici
    cattura_re(Fazione, P4, PezziFinali).

% Logica del Sandwich per i normali SOLDATI
cattura_direzione(X, Y, DX, DY, MiaFazione, PezziIn, PezziOut) :-
    Nx is X + DX, Ny is Y + DY,             
    Ox is Nx + DX, Oy is Ny + DY,           
    avversario(MiaFazione, Nemico),
    % Limito la cattura a panino generica solo ai "soldati" nemici
    ( select(pezzo(soldato, Nemico, Nx, Ny), PezziIn, Resto) ->
        ( member(pezzo(_, MiaFazione, Ox, Oy), PezziIn) ; casella_speciale(Ox, Oy) ) ->
            PezziOut = Resto 
        ; PezziOut = PezziIn 
    ; PezziOut = PezziIn     
    ).

% --- LOGICA DI CATTURA DEL RE (REGOLE TABLUT STORICHE) ---
cattura_re(difensore, Pezzi, Pezzi). % Il difensore non può auto-uccidersi il Re
cattura_re(attaccante, Pezzi, PezziFinali) :-
    ( member(pezzo(re, difensore, RX, RY), Pezzi),
      re_in_trappola(RX, RY, Pezzi) ->
      select(pezzo(re, difensore, RX, RY), Pezzi, PezziFinali)
    ; PezziFinali = Pezzi
    ).

% Caso A: Re sul Trono (5,5) -> Richiede 4 attaccanti (circondato totalmente)
re_in_trappola(5, 5, Pezzi) :-
    ostile_al_re(5, 5, 0, -1, Pezzi),
    ostile_al_re(5, 5, 0, 1, Pezzi),
    ostile_al_re(5, 5, -1, 0, Pezzi),
    ostile_al_re(5, 5, 1, 0, Pezzi).

% Caso B: Re adiacente al Trono -> Richiede 3 attaccanti (il 4° lato è il trono ostile)
re_in_trappola(RX, RY, Pezzi) :-
    adiacente_al_trono(RX, RY),
    ostile_al_re(RX, RY, 0, -1, Pezzi),
    ostile_al_re(RX, RY, 0, 1, Pezzi),
    ostile_al_re(RX, RY, -1, 0, Pezzi),
    ostile_al_re(RX, RY, 1, 0, Pezzi).

% Caso C: Re in campo aperto -> Cattura Sandwich normale (basta che sia chiuso su 2 lati opposti!)
re_in_trappola(RX, RY, Pezzi) :-
    \+ (RX = 5, RY = 5),
    \+ adiacente_al_trono(RX, RY),
    (
        (ostile_al_re(RX, RY, 0, -1, Pezzi), ostile_al_re(RX, RY, 0, 1, Pezzi)) ; % Panino Verticale
        (ostile_al_re(RX, RY, -1, 0, Pezzi), ostile_al_re(RX, RY, 1, 0, Pezzi))   % Panino Orizzontale
    ).

% Helper: Coordinate adiacenti al Trono
adiacente_al_trono(4, 5).
adiacente_al_trono(6, 5).
adiacente_al_trono(5, 4).
adiacente_al_trono(5, 6).

% Una casella adiacente al Re è "ostile" se contiene un attaccante o è speciale (Trono/Angoli)
ostile_al_re(RX, RY, DX, DY, Pezzi) :-
    NX is RX + DX, NY is RY + DY,
    ( member(pezzo(_, attaccante, NX, NY), Pezzi) ; casella_speciale(NX, NY) ).

avversario(difensore, attaccante).
avversario(attaccante, difensore).

% --- 3. CONDIZIONI DI VITTORIA ---
vittoria(Pezzi, difensore) :-
    % Il difensore vince se il Re è su uno dei 4 angoli
    member(pezzo(re, difensore, X, Y), Pezzi),
    casella_speciale(X, Y), X \= 5. 

vittoria(Pezzi, attaccante) :-
    % L'attaccante vince se non c'è più il Re sulla plancia
    \+ member(pezzo(re, difensore, _, _), Pezzi).
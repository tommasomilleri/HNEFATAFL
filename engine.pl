% =========================================================
% MODULO: engine.pl
% Scopo: Regole di Hnefatafl, Catture e Vittoria
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

% --- 2. APPLICAZIONE MOSSA E CATTURE (SANDWICH) ---
% Sposta il pezzo ed elimina eventuali nemici mangiati
applica_mossa(X0, Y0, X1, Y1, Pezzi, PezziFinali) :-
    select(pezzo(Tipo, Fazione, X0, Y0), Pezzi, Resto),
    PezziMossi = [pezzo(Tipo, Fazione, X1, Y1) | Resto],
    % Dopo aver mosso, controllo in tutte e 4 le direzioni se ho schiacciato qualcuno
    cattura_direzione(X1, Y1, 0, -1, Fazione, PezziMossi, P1), % Nord
    cattura_direzione(X1, Y1, 0, 1, Fazione, P1, P2),          % Sud
    cattura_direzione(X1, Y1, -1, 0, Fazione, P2, P3),         % Ovest
    cattura_direzione(X1, Y1, 1, 0, Fazione, P3, PezziFinali). % Est

% Logica del Sandwich: Guardo a distanza 1 (Nemico) e distanza 2 (Incudine)
cattura_direzione(X, Y, DX, DY, MiaFazione, PezziIn, PezziOut) :-
    Nx is X + DX, Ny is Y + DY,             % Casella adiacente (dove starebbe il nemico)
    Ox is Nx + DX, Oy is Ny + DY,           % Casella oltre il nemico (la nostra "incudine")
    avversario(MiaFazione, Nemico),
    % Se nella casella adiacente c'è un soldato nemico (il Re si mangia diversamente, semplifichiamo per ora)
    ( select(pezzo(soldato, Nemico, Nx, Ny), PezziIn, Resto) ->
        % Se l'incudine è un MIO pezzo OPPURE è una casella speciale (Trono/Angolo fungono da muro)
        ( member(pezzo(_, MiaFazione, Ox, Oy), PezziIn) ; casella_speciale(Ox, Oy) ) ->
            PezziOut = Resto % Sandwich confermato! Rimuovo il nemico.
        ; PezziOut = PezziIn % Niente incudine, non lo mangio.
    ; PezziOut = PezziIn     % Nessun nemico adiacente.
    ).

avversario(difensore, attaccante).
avversario(attaccante, difensore).

% --- 3. CONDIZIONI DI VITTORIA ---
vittoria(Pezzi, difensore) :-
    % Il difensore vince se il Re è su uno dei 4 angoli
    member(pezzo(re, difensore, X, Y), Pezzi),
    casella_speciale(X, Y), X \= 5. 

vittoria(Pezzi, attaccante) :-
    % L'attaccante vince se non c'è più il Re sulla plancia (mangiato)
    \+ member(pezzo(re, difensore, _, _), Pezzi).
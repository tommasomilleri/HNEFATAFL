% =========================================================
% Regole di movimento, Catture storiche e Vittoria
% =========================================================

:- module(engine, [mossa_legale/5, applica_mossa/6, vittoria/2]). % module dichiara che questo file si chama engine. tra parentesi graffe i predicati pubblici con aritá. 
:- use_module(kb). %use_module per importare i predicati da kb.pl. 

% VALIDAZIONE MOSSA (Posso prendere pezzo da X0,Y0 e metterlo in X1,Y1? Vero/Falso) ---
mossa_legale(X0, Y0, X1, Y1, Pezzi) :-
    member(pezzo(Tipo, _Fazione, X0, Y0), Pezzi), %
    kb:dimensione(Max),
    between(1, Max, X1), between(1, Max, Y1),
    mossa_ortogonale(X0, Y0, X1, Y1),
    \+ member(pezzo(_, _, X1, Y1), Pezzi), 

    % REGOLA: Solo il Re può fermarsi sul trono o negli angoli
    (Tipo \= re -> \+ casella_speciale(X1, Y1) ; true), %se tipo del pezzo è diverso da re allora controlla che la destinazione NON (\+) sia una casella speciale, altrimenti (;) se é un re, restituisce true.
    % Verifica rapida ostacoli
    percorso_libero(X0, Y0, X1, Y1, Pezzi).

mossa_ortogonale(X0, Y, X1, Y) :- X0 \= X1.
mossa_ortogonale(X, Y0, X, Y1) :- Y0 \= Y1.

% Ricorsione pura al posto di forall/between per passare da tempi di circa 30 s a poco piu di 1 s.
percorso_libero(X0, Y, X1, Y, Pezzi) :- %percorso_libero orizzontale 
    X0 \= X1, 
    MinX is min(X0, X1) + 1, MaxX is max(X0, X1) - 1, %calcolo la casella di partenza esatta (MinX) e quella finale (MaxX), escludendo la pedina stessa.
    nessun_pezzo_x(MinX, MaxX, Y, Pezzi).
percorso_libero(X, Y0, X, Y1, Pezzi) :- %percorso_libero verticale
    Y0 \= Y1, 
    MinY is min(Y0, Y1) + 1, %se parto dalla casella 2 devo controllare dalle 2+1=3 in avanti
    MaxY is max(Y0, Y1) - 1, %se voglio arrivare alla 8 devo controllare fino alla 8-1=7
    nessun_pezzo_y(MinY, MaxY, X, Pezzi).

nessun_pezzo_x(Min, Max, _, _) :- %se movimento ha successo non mi importa su che Y ero e come era fatta la scacchiera.
Min > Max, !. %se Min ha superato la meta Max, si ferma e restituisce true (la via é libera).
nessun_pezzo_x(Min, Max, Y, Pezzi) :- 
\+ member(pezzo(_, _, Min, Y), Pezzi), %controlla che non ci sia un pezzo in quella casella (Min, Y) e 
    Next is Min + 1, nessun_pezzo_x(Next, Max, Y, Pezzi). %aggiunge +1 al contatore Min per controllare la casella successiva, fino a raggiungere Max.

nessun_pezzo_y(Min, Max, _, _) :- Min > Max, !.
nessun_pezzo_y(Min, Max, X, Pezzi) :- 
\+ member(pezzo(_, _, X, Min), Pezzi), %controllo che non ci sia un pezzo (non interessa di che fazione appartenga))
    Next is Min + 1, nessun_pezzo_y(Next, Max, X, Pezzi). %va avanti fino a raggiungere Max, se non trova pezzi restituisce true (la via é libera).

% Definiamo Trono e Angoli attraverso FACTS (fatti)
casella_speciale(5, 5). % Trono
casella_speciale(1, 1). casella_speciale(1, 9).
casella_speciale(9, 1). casella_speciale(9, 9).

% APPLICAZIONE MOSSA E CATTURE ---
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
% acronimi: - DX, DY = Direzione di movimento, 
%           - Nx, Ny = Casella del Nemico, 
%           - Ox, Oy = Casella Oltre il nemici (la potenziale incudine)



cattura_direzione(X, Y, DX, DY, MiaFazione, PezziIn, PezziOut) :-
    Nx is X + DX, Ny is Y + DY,%calcola le coordinate della cella adiacente nella direzionie di moviemento.
    avversario(MiaFazione, Nemico), %chiede al database "avversario" chi è il nemico rispetto alla mia fazione
    % Lazy Evaluation: Calcola l'incudine SOLO se abbiamo trovato un nemico in mezzo (risparmia CPU)
( select(pezzo(soldato, Nemico, Nx, Ny), PezziIn, Resto) -> %cerca esattamente un pezzo che corrisponde al nemico e che sia un soldato, se lo trova restituisce Resto (la lista dei pezzi senza il nemico catturato) e continua sotto...
        Ox is Nx + DX, Oy is Ny + DY, % calcolando le coordinate della casella oltre il nemico (la potenziale incudine)
        % REGOLA DI COPENHAGEN: Una casella speciale fa da incudine SOLO SE È VUOTA!
        (
        ( member(pezzo(_, MiaFazione, Ox, Oy), PezziIn) ; %controlla se nella casella oltre il nemico c'è un pezzo amico (cattura standard) oppure (;)...
          (casella_speciale(Ox, Oy), \+ member(pezzo(_, _, Ox, Oy), PezziIn)) %...se è una casella speciale ma è VUOTA
        ) -> %allora
            PezziOut = Resto %il nemico è stato catturato, restituisco la lista dei pezzi senza il nemico catturato
        ; PezziOut = PezziIn  % se riga 82 fallisce, resituisco la lista originale
        )
    ; PezziOut = PezziIn %se riga 76 fallisce, restituisco la lista originale (non c'è un nemico da catturare in questa direzione)
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
    NX is RX + DX, NY is RY + DY,%Rx si
    ( member(pezzo(_, attaccante, NX, NY), Pezzi) ; %
      (casella_speciale(NX, NY), \+ member(pezzo(_, _, NX, NY), Pezzi))%controlla se la casella adiacente è una casella speciale e che sia vuota (non ci sia un pezzo di nessuna fazione)
    ).

avversario(difensore, attaccante).
avversario(attaccante, difensore).

% --- 3. CONDIZIONI DI VITTORIA ---
vittoria(Pezzi, difensore) :- 
    member(pezzo(re, difensore, X, Y), Pezzi), %
    casella_speciale(X, Y), X \= 5, !.

vittoria(Pezzi, attaccante) :- %é una vittoria per gli attaccanti se il re è stato catturato, ovvero se non è più presente nella lista dei pezzi.
    \+ member(pezzo(re, difensore, _, _), Pezzi), !.
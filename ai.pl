% =========================================================
% MODULO: ai.pl (AI Avanzata con Alpha-Beta Pruning)
% =========================================================

:- module(ai, [calcola_mossa_ai/4]).
:- use_module(engine).
:- use_module(kb).
:- use_module(library(random)).

% --- ENTRY POINT: Calcolo della mossa migliore ---
calcola_mossa_ai(Pezzi, FazioneAI, Profondita, MossaScelta) :-
    % 1. Trova tutte le mosse legali
    findall(mossa(FX, FY, TX, TY, NuoviPezzi), genera_mossa_valida(Pezzi, FazioneAI, FX, FY, TX, TY, NuoviPezzi), MossePossibili),
    MossePossibili \= [], 
    
    % 2. Mischiamo le mosse per evitare pattern ripetitivi a parità di punteggio
    random_permutation(MossePossibili, MosseMischiate),
    
    % 3. Avviamo la ricerca Alpha-Beta dal nodo radice
    % Inizializziamo Alpha = -10000 e Beta = 10000
    Alpha = -10000,
    Beta = 10000,
    valuta_radice(MosseMischiate, FazioneAI, Profondita, Alpha, Beta, -10000, mossa(-1,-1,-1,-1), MossaScelta, _PunteggioMigliore).

% --- CICLO RADICE ---
% valuta_radice(Mosse, Fazione, Prof, Alpha, Beta, MigliorValoreFinora, MigliorMossaFinora, MossaFinale, ValoreFinale)
valuta_radice([], _, _, _, _, ValoreTop, MossaTop, MossaTop, ValoreTop).
valuta_radice([mossa(FX, FY, TX, TY, NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreTop, MossaTop, MossaFinale, ValoreFinale) :-
    % Valutiamo la mossa corrente passando il turno all'avversario (TurnoAI = false)
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreAttuale),
    
    % Aggiorniamo la mossa migliore se il valore attuale è più alto
    ( ValoreAttuale > ValoreTop ->
        NuovoValoreTop = ValoreAttuale,
        NuovaMossaTop = mossa(FX, FY, TX, TY)
    ;
        NuovoValoreTop = ValoreTop,
        NuovaMossaTop = MossaTop
    ),
    
    % Aggiorniamo Alpha
    NuovoAlpha is max(Alpha, NuovoValoreTop),
    
    % Controlliamo il Pruning (Taglio del ramo)
    ( NuovoAlpha >= Beta ->
        MossaFinale = NuovaMossaTop, ValoreFinale = NuovoValoreTop
    ;
        % Continuiamo con la prossima mossa
        valuta_radice(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoValoreTop, NuovaMossaTop, MossaFinale, ValoreFinale)
    ).

% --- ALGORITMO ALPHA-BETA PRUNING ---
% alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, TurnoAI, Punteggio).

% Condizioni di terminazione: Vittoria o Fine Profondità
alphabeta(Pezzi, _, _, _, FazioneAI, _, 10000) :- engine:vittoria(Pezzi, FazioneAI), !.
alphabeta(Pezzi, _, _, _, FazioneAI, _, -10000) :- avversario(FazioneAI, Avv), engine:vittoria(Pezzi, Avv), !.
alphabeta(Pezzi, 0, _, _, FazioneAI, _, Punteggio) :- !, euristica(Pezzi, FazioneAI, Punteggio).

% NODO MAX (Turno dell'Intelligenza Artificiale)
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, true, PunteggioMassimo) :-
    Profondita > 0,
    findall(mossa(FX, FY, TX, TY, NP), genera_mossa_valida(Pezzi, FazioneAI, FX, FY, TX, TY, NP), Figli),
    ( Figli = [] -> PunteggioMassimo = -10000 % Niente mosse = Sconfitta
    ; NuovaProf is Profondita - 1,
      valuta_max(Figli, FazioneAI, NuovaProf, Alpha, Beta, -10000, PunteggioMassimo)
    ).

% NODO MIN (Turno dell'Avversario Umano)
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, false, PunteggioMinimo) :-
    Profondita > 0,
    avversario(FazioneAI, Nemico),
    findall(mossa(FX, FY, TX, TY, NP), genera_mossa_valida(Pezzi, Nemico, FX, FY, TX, TY, NP), Figli),
    ( Figli = [] -> PunteggioMinimo = 10000 % Niente mosse nemico = Vittoria
    ; NuovaProf is Profondita - 1,
      valuta_min(Figli, FazioneAI, NuovaProf, Alpha, Beta, 10000, PunteggioMinimo)
    ).

% iterazione sui figli del NODO MAX
valuta_max([], _, _, _, _, MigliorValore, MigliorValore).
valuta_max([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreFiglio),
    NuovoValoreMax is max(ValoreAttuale, ValoreFiglio),
    NuovoAlpha is max(Alpha, NuovoValoreMax),
    ( NuovoAlpha >= Beta ->
        ValoreFinale = NuovoValoreMax % PRUNING!
    ;
        valuta_max(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoValoreMax, ValoreFinale)
    ).

% iterazione sui figli del NODO MIN
valuta_min([], _, _, _, _, MigliorValore, MigliorValore).
valuta_min([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, true, ValoreFiglio),
    NuovoValoreMin is min(ValoreAttuale, ValoreFiglio),
    NuovoBeta is min(Beta, NuovoValoreMin),
    ( Alpha >= NuovoBeta ->
        ValoreFinale = NuovoValoreMin % PRUNING!
    ;
        valuta_min(Resto, FazioneAI, Prof, Alpha, NuovoBeta, NuovoValoreMin, ValoreFinale)
    ).

% --- EURISTICA MIGLIORATA ---
% Ora valuta non solo la distanza dal centro, ma penalizza enormemente l'attaccante 
% se il Re raggiunge il bordo (e viceversa per il difensore).

euristica(Pezzi, attaccante, Punteggio) :-
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5),
        % Se il Re è sul bordo, è panico per l'attaccante!
        ( (RX =:= 1 ; RX =:= 9 ; RY =:= 1 ; RY =:= 9) -> BordoMalus = 500 ; BordoMalus = 0 )
    ; DistanzaCentro = 0, BordoMalus = 0 
    ),
    PunteggioBase is (NumAtt * 30) - (NumDif * 40), % Le pedine contano di più ora
    Punteggio is PunteggioBase - (DistanzaCentro * 15) - BordoMalus.

euristica(Pezzi, difensore, Punteggio) :-
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5),
        % Se il Re è sul bordo, vittoria vicina per il difensore!
        ( (RX =:= 1 ; RX =:= 9 ; RY =:= 1 ; RY =:= 9) -> BordoBonus = 500 ; BordoBonus = 0 )
    ; DistanzaCentro = 0, BordoBonus = 0 
    ),
    PunteggioBase is (NumDif * 40) - (NumAtt * 30),
    Punteggio is PunteggioBase + (DistanzaCentro * 20) + BordoBonus.

% --- UTILS ---
genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NuoviPezzi) :-
    member(pezzo(_Tipo, Fazione, FX, FY), Pezzi),
    kb:dimensione(Max),
    ( between(1, Max, TX), TX \= FX, TY = FY ; between(1, Max, TY), TY \= FY, TX = FX ),
    engine:mossa_legale(FX, FY, TX, TY, Pezzi),
    engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi).

avversario(difensore, attaccante).
avversario(attaccante, difensore).
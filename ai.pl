% =========================================================
% MODULO: ai.pl (Motore Scacchistico - PROFONDITÀ 5)
% Tecniche: Alpha-Beta + Move Ordering + Imbuto Dinamico
% =========================================================

:- module(ai, [calcola_mossa_ai/4, avversario/2]).
:- use_module(engine).
:- use_module(kb).
:- use_module(library(random)).

% --- ENTRY POINT ---
calcola_mossa_ai(Pezzi, FazioneAI, Profondita, MossaScelta) :-
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    MosseOrdinate \= [], 
    
    % IMBUTO (LIVELLO RADICE): Essendo il primo passo, guardiamo un ventaglio largo
    LimiteRadice is Profondita * 4, % Se Prof=5, analizza le prime 20 mosse migliori
    prendi_primi(LimiteRadice, MosseOrdinate, MosseTop), 
    
    Alpha = -100000,
    Beta = 100000,
    valuta_radice(MosseTop, FazioneAI, Profondita, Alpha, Beta, -100000, mossa(-1,-1,-1,-1), MossaScelta, _Punteggio).

% --- MOVE ORDERING (Riconosce le mosse letali a colpo d'occhio) ---
genera_mosse_ordinate(Pezzi, Fazione, MosseOrdinate) :-
    findall(
        Score-mossa(FX, FY, TX, TY, NP),
        (
            genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NP),
            quick_eval(Pezzi, NP, Score)
        ),
        MosseConScore
    ),
    keysort(MosseConScore, MosseAscendenti),
    reverse(MosseAscendenti, MosseOrdinate).

quick_eval(VecchiPezzi, NuoviPezzi, Score) :-
    length(VecchiPezzi, L1),
    length(NuoviPezzi, L2),
    PezziMangiati is L1 - L2,
    random_between(0, 9, Rand), % Leggera dose di fantasia per non ripetere gli stessi pattern
    Score is (PezziMangiati * 1000) + Rand.

prendi_primi(0, _, []) :- !.
prendi_primi(_, [], []) :- !.
prendi_primi(N, [_Score-Mossa | T], [Mossa | R]) :-
    N > 0, N1 is N - 1,
    prendi_primi(N1, T, R).

% --- CICLO RADICE ---
valuta_radice([], _, _, _, _, ValoreTop, MossaTop, MossaTop, ValoreTop).
valuta_radice([mossa(FX, FY, TX, TY, NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreTop, MossaTop, MossaFinale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreAttuale),
    ( ValoreAttuale > ValoreTop ->
        NuovoValoreTop = ValoreAttuale, NuovaMossaTop = mossa(FX, FY, TX, TY)
    ;   NuovoValoreTop = ValoreTop, NuovaMossaTop = MossaTop
    ),
    NuovoAlpha is max(Alpha, NuovoValoreTop),
    ( NuovoAlpha >= Beta ->
        MossaFinale = NuovaMossaTop, ValoreFinale = NuovoValoreTop
    ;   valuta_radice(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoValoreTop, NuovaMossaTop, MossaFinale, ValoreFinale)
    ).

% --- ALPHA-BETA PRUNING (Con Filtro Dinamico) ---
alphabeta(Pezzi, _, _, _, FazioneAI, _, 100000) :- engine:vittoria(Pezzi, FazioneAI), !.
alphabeta(Pezzi, _, _, _, FazioneAI, _, -100000) :- avversario(FazioneAI, Avv), engine:vittoria(Pezzi, Avv), !.
alphabeta(Pezzi, 0, _, _, FazioneAI, _, Punteggio) :- !, euristica(Pezzi, FazioneAI, Punteggio).

% NODO MAX (Turno dell'AI)
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, true, PunteggioMassimo) :-
    Profondita > 0,
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    
    % IMBUTO DINAMICO: Più andiamo in profondità, più stringiamo il raggio d'azione
    Limite is max(3, Profondita * 2), 
    prendi_primi(Limite, MosseOrdinate, Figli), 
    
    ( Figli = [] -> PunteggioMassimo = -100000 
    ; NuovaProf is Profondita - 1,
      valuta_max(Figli, FazioneAI, NuovaProf, Alpha, Beta, -100000, PunteggioMassimo)
    ).

% NODO MIN (Turno del Giocatore)
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, false, PunteggioMinimo) :-
    Profondita > 0,
    avversario(FazioneAI, Nemico),
    genera_mosse_ordinate(Pezzi, Nemico, MosseOrdinate),
    
    Limite is max(3, Profondita * 2), 
    prendi_primi(Limite, MosseOrdinate, Figli), 
    
    ( Figli = [] -> PunteggioMinimo = 100000 
    ; NuovaProf is Profondita - 1,
      valuta_min(Figli, FazioneAI, NuovaProf, Alpha, Beta, 100000, PunteggioMinimo)
    ).

valuta_max([], _, _, _, _, Valore, Valore).
valuta_max([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreFiglio),
    NuovoMax is max(ValoreAttuale, ValoreFiglio),
    NuovoAlpha is max(Alpha, NuovoMax),
    ( NuovoAlpha >= Beta -> ValoreFinale = NuovoMax
    ; valuta_max(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoMax, ValoreFinale)
    ).

valuta_min([], _, _, _, _, Valore, Valore).
valuta_min([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, true, ValoreFiglio),
    NuovoMin is min(ValoreAttuale, ValoreFiglio),
    NuovoBeta is min(Beta, NuovoMin),
    ( Alpha >= NuovoBeta -> ValoreFinale = NuovoMin
    ; valuta_min(Resto, FazioneAI, Prof, Alpha, NuovoBeta, NuovoMin, ValoreFinale)
    ).

% --- EURISTICA ESTREMA ---
euristica(Pezzi, attaccante, Punteggio) :-
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5),
        ( (RX =:= 1 ; RX =:= 9 ; RY =:= 1 ; RY =:= 9) -> BordoMalus = 5000 ; BordoMalus = 0 )
    ; DistanzaCentro = 0, BordoMalus = 0 
    ),
    PunteggioBase is (NumAtt * 60) - (NumDif * 80), 
    Punteggio is PunteggioBase - (DistanzaCentro * 20) - BordoMalus.

euristica(Pezzi, difensore, Punteggio) :-
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5),
        ( (RX =:= 1 ; RX =:= 9 ; RY =:= 1 ; RY =:= 9) -> BordoBonus = 5000 ; BordoBonus = 0 )
    ; DistanzaCentro = 0, BordoBonus = 0 
    ),
    PunteggioBase is (NumDif * 80) - (NumAtt * 60),
    Punteggio is PunteggioBase + (DistanzaCentro * 30) + BordoBonus.

% --- UTILS ---
genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NuoviPezzi) :-
    member(pezzo(_Tipo, Fazione, FX, FY), Pezzi),
    kb:dimensione(Max),
    ( between(1, Max, TX), TX \= FX, TY = FY ; between(1, Max, TY), TY \= FY, TX = FX ),
    engine:mossa_legale(FX, FY, TX, TY, Pezzi),
    engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi).

avversario(difensore, attaccante).
avversario(attaccante, difensore).
/*
% =========================================================
% MODULO: ai.pl (L'IA "GOD MODE" - PROFONDITÀ ESTREMA 7)
% Tecniche: Alpha-Beta + Razor Beam Search + God-Tier Heuristic
% =========================================================

:- module(ai, [calcola_mossa_ai/4, avversario/2]).
:- use_module(engine).
:- use_module(kb).
:- use_module(library(random)).
:- use_module(library(lists)).

% --- ENTRY POINT ---
calcola_mossa_ai(Pezzi, FazioneAI, Profondita, MossaScelta) :-
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    MosseOrdinate \= [], 
    
    % IMBUTO RADICE: Legge la larghezza dal nuovo filtro a Lama di Rasoio
    beam_width(Profondita, LimiteRadice), 
    prendi_primi(LimiteRadice, MosseOrdinate, MosseTop), 
    
    Alpha = -1000000,
    Beta = 1000000,
    valuta_radice(MosseTop, FazioneAI, Profondita, Alpha, Beta, -1000000, mossa(-1,-1,-1,-1), MossaScelta, _Punteggio).

% --- IL FILTRO "LAMA DI RASOIO" (Razor Beam Search) ---
% Per sopravvivere a profondità 7, l'IA deve scartare le mosse inutili all'istante.
% I calcoli totali massimi saranno: 12 * 8 * 6 * 4 * 3 * 2 * 1 = 13.824 rami. Istantaneo!
beam_width(Depth, W) :- Depth >= 7, W = 12, !.
beam_width(6, 8) :- !.
beam_width(5, 6) :- !.
beam_width(4, 4) :- !.
beam_width(3, 3) :- !.
beam_width(2, 2) :- !.
beam_width(1, 1) :- !.
beam_width(_, 5). % Sicurezza

% --- MOVE ORDERING (Istinto Omicida) ---
genera_mosse_ordinate(Pezzi, Fazione, MosseOrdinate) :-
    findall(
        Score-mossa(FX, FY, TX, TY, NP),
        (
            genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NP),
            quick_eval(NP, Fazione, Score)
        ),
        MosseConScore
    ),
    keysort(MosseConScore, MosseAscendenti),
    reverse(MosseAscendenti, MosseOrdinate).

quick_eval(NuoviPezzi, Fazione, Score) :-
    ( engine:vittoria(NuoviPezzi, Fazione) -> 
        Score = 1000000 % Mossa letale trovata: precedenza assoluta!
    ; 
        length(NuoviPezzi, L2), 
        random_between(0, 9, Rand), 
        Score is (-L2 * 1000) + Rand
    ).

prendi_primi(0, _, []) :- !.
prendi_primi(_, [], []) :- !.
prendi_primi(N, [_Score-Mossa | T], [Mossa | R]) :-
    N > 0, N1 is N - 1,
    prendi_primi(N1, T, R).

% --- CICLO RADICE ALPHA-BETA ---
valuta_radice([], _, _, _, _, ValoreTop, MossaTop, MossaTop, ValoreTop).
valuta_radice([mossa(FX, FY, TX, TY, NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreTop, MossaTop, MossaFinale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreAttuale),
    ( ValoreAttuale > ValoreTop ->
        NuovoValoreTop = ValoreAttuale, NuovaMossaTop = mossa(FX, FY, TX, TY)
    ;   NuovoValoreTop = ValoreTop, NuovaMossaTop = MossaTop
    ),
    NuovoAlpha is max(Alpha, NuovoValoreTop),
    ( NuovoAlpha >= Beta ->
        MossaFinale = NuovaMossaTop, ValoreFinale = NuovoValoreTop
    ;   valuta_radice(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoValoreTop, NuovaMossaTop, MossaFinale, ValoreFinale)
    ).

% --- ALGORITMO ALPHA-BETA PRUNING ---
alphabeta(Pezzi, _, _, _, FazioneAI, _, 1000000) :- engine:vittoria(Pezzi, FazioneAI), !.
alphabeta(Pezzi, _, _, _, FazioneAI, _, -1000000) :- avversario(FazioneAI, Avv), engine:vittoria(Pezzi, Avv), !.
alphabeta(Pezzi, 0, _, _, FazioneAI, _, Punteggio) :- !, euristica(Pezzi, FazioneAI, Punteggio).

% NODO MAX
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, true, PunteggioMassimo) :-
    Profondita > 0,
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    beam_width(Profondita, Limite),
    prendi_primi(Limite, MosseOrdinate, Figli), 
    ( Figli = [] -> PunteggioMassimo = -1000000 
    ; NuovaProf is Profondita - 1,
      valuta_max(Figli, FazioneAI, NuovaProf, Alpha, Beta, -1000000, PunteggioMassimo)
    ).

% NODO MIN
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, false, PunteggioMinimo) :-
    Profondita > 0,
    avversario(FazioneAI, Nemico),
    genera_mosse_ordinate(Pezzi, Nemico, MosseOrdinate),
    beam_width(Profondita, Limite),
    prendi_primi(Limite, MosseOrdinate, Figli), 
    ( Figli = [] -> PunteggioMinimo = 1000000 
    ; NuovaProf is Profondita - 1,
      valuta_min(Figli, FazioneAI, NuovaProf, Alpha, Beta, 1000000, PunteggioMinimo)
    ).

valuta_max([], _, _, _, _, Valore, Valore).
valuta_max([NP | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreFiglio),
    NuovoMax is max(ValoreAttuale, ValoreFiglio),
    NuovoAlpha is max(Alpha, NuovoMax),
    ( NuovoAlpha >= Beta -> ValoreFinale = NuovoMax
    ; valuta_max(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoMax, ValoreFinale)
    ).

valuta_min([], _, _, _, _, Valore, Valore).
valuta_min([NP | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, true, ValoreFiglio),
    NuovoMin is min(ValoreAttuale, ValoreFiglio),
    NuovoBeta is min(Beta, NuovoMin),
    ( Alpha >= NuovoBeta -> ValoreFinale = NuovoMin
    ; valuta_min(Resto, FazioneAI, Prof, Alpha, NuovoBeta, NuovoMin, ValoreFinale)
    ).

% --- EURISTICA DIVINA ---
euristica(Pezzi, Fazione, Punteggio) :-
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),

    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        min_distanza_angolo(RX, RY, DistAngolo),
        findall(1, (member(pezzo(_, attaccante, AX, AY), Pezzi), abs(AX-RX)+abs(AY-RY) =:= 1), LMinacce),
        length(LMinacce, MinacceRe)
    ;
        DistAngolo = 99, MinacceRe = 0
    ),

    ValoreAttaccanti is NumAtt * 100,
    ValoreDifensori is NumDif * 150, 

    ( Fazione == attaccante ->
        Punteggio is ValoreAttaccanti - ValoreDifensori + (DistAngolo * 80) + (MinacceRe * 300)
    ;
        Punteggio is ValoreDifensori - ValoreAttaccanti - (DistAngolo * 100) - (MinacceRe * 400)
    ).

min_distanza_angolo(RX, RY, MinDist) :-
    D1 is abs(RX - 1) + abs(RY - 1),
    D2 is abs(RX - 1) + abs(RY - 9),
    D3 is abs(RX - 9) + abs(RY - 1),
    D4 is abs(RX - 9) + abs(RY - 9),
    MinDist is min(min(D1, D2), min(D3, D4)).

% --- UTILS ---
genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NuoviPezzi) :-
    member(pezzo(_Tipo, Fazione, FX, FY), Pezzi),
    kb:dimensione(Max),
    ( between(1, Max, TX), TX \= FX, TY = FY ; between(1, Max, TY), TY \= FY, TX = FX ),
    engine:mossa_legale(FX, FY, TX, TY, Pezzi),
    engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi).

avversario(difensore, attaccante).
avversario(attaccante, difensore).*/
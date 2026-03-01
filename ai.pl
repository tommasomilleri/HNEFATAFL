% =========================================================
% MODULO: ai.pl (Intelligenza Artificiale Imprevedibile)
% =========================================================

:- module(ai, [calcola_mossa_ai/4]).
:- use_module(engine).
:- use_module(kb).
:- use_module(library(random)). % <--- AGGIUNTA LA LIBRERIA RANDOM!

calcola_mossa_ai(Pezzi, FazioneAI, Profondita, MossaScelta) :-
    % 1. Trova tutte le mosse legali possibili
    findall(mossa(FX, FY, TX, TY, NuoviPezzi), genera_mossa_valida(Pezzi, FazioneAI, FX, FY, TX, TY, NuoviPezzi), MossePossibili),
    MossePossibili \= [], % Sicurezza
    
    % 2. MISCHIAMO LE MOSSE! (Il trucco per rendere l'AI non ripetitiva)
    random_permutation(MossePossibili, MosseMischiate),
    
    % 3. Valuta i rami (ora in ordine casuale)
    valuta_tutte_mosse(MosseMischiate, FazioneAI, Profondita, MosseValutate),
    
    % 4. Ordina in base al punteggio (keysort preserva l'ordine casuale in caso di parità!)
    keysort(MosseValutate, Ascendente),
    reverse(Ascendente, [_MigliorPunteggio-MossaScelta | _]).

valuta_tutte_mosse([], _, _, []).
valuta_tutte_mosse([mossa(FX, FY, TX, TY, NP) | Resto], FazioneAI, Profondita, [Punteggio-mossa(FX,FY,TX,TY) | RestoValutate]) :-
    minimax(NP, Profondita, FazioneAI, false, Punteggio),
    valuta_tutte_mosse(Resto, FazioneAI, Profondita, RestoValutate).

% --- MINIMAX ---
minimax(Pezzi, _, FazioneAI, _, 10000) :- engine:vittoria(Pezzi, FazioneAI), !.
minimax(Pezzi, _, FazioneAI, _, -10000) :- avversario(FazioneAI, Avv), engine:vittoria(Pezzi, Avv), !.
minimax(Pezzi, 0, FazioneAI, _, Punteggio) :- !, euristica(Pezzi, FazioneAI, Punteggio).

minimax(Pezzi, Profondita, FazioneAI, true, PunteggioMassimo) :-
    Profondita > 0,
    findall(mossa(FX, FY, TX, TY, NP), genera_mossa_valida(Pezzi, FazioneAI, FX, FY, TX, TY, NP), Figli),
    ( Figli = [] -> PunteggioMassimo = -10000 
    ; NuovaProf is Profondita - 1,
      valuta_figli(Figli, FazioneAI, NuovaProf, false, PunteggiFigli),
      max_list(PunteggiFigli, PunteggioMassimo)
    ).

minimax(Pezzi, Profondita, FazioneAI, false, PunteggioMinimo) :-
    Profondita > 0,
    avversario(FazioneAI, Avversario),
    findall(mossa(FX, FY, TX, TY, NP), genera_mossa_valida(Pezzi, Avversario, FX, FY, TX, TY, NP), Figli),
    ( Figli = [] -> PunteggioMinimo = 10000 
    ; NuovaProf is Profondita - 1,
      valuta_figli(Figli, FazioneAI, NuovaProf, true, PunteggiFigli),
      min_list(PunteggiFigli, PunteggioMinimo)
    ).

valuta_figli([], _, _, _, []).
valuta_figli([mossa(_, _, _, _, NP) | Resto], FazioneAI, Prof, TurnoAI, [P | RestoP]) :-
    minimax(NP, Prof, FazioneAI, TurnoAI, P),
    valuta_figli(Resto, FazioneAI, Prof, TurnoAI, RestoP).

% --- EURISTICA ---
euristica(Pezzi, attaccante, Punteggio) :-
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5)
    ; DistanzaCentro = 10 
    ),
    PunteggioBase is (NumAtt * 10) - (NumDif * 15),
    Punteggio is PunteggioBase - (DistanzaCentro * 5).

euristica(Pezzi, difensore, Punteggio) :-
    findall(1, member(pezzo(_, difensore, _, _), Pezzi), LDif), length(LDif, NumDif),
    findall(1, member(pezzo(_, attaccante, _, _), Pezzi), LAtt), length(LAtt, NumAtt),
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        DistanzaCentro is abs(RX - 5) + abs(RY - 5)
    ; DistanzaCentro = -10 
    ),
    PunteggioBase is (NumDif * 15) - (NumAtt * 10),
    Punteggio is PunteggioBase + (DistanzaCentro * 10).

% --- UTILS ---
genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NuoviPezzi) :-
    member(pezzo(_Tipo, Fazione, FX, FY), Pezzi),
    kb:dimensione(Max),
    ( between(1, Max, TX), TX \= FX, TY = FY ; between(1, Max, TY), TY \= FY, TX = FX ),
    engine:mossa_legale(FX, FY, TX, TY, Pezzi),
    engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi).

avversario(difensore, attaccante).
avversario(attaccante, difensore).
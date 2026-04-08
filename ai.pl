
% Concetti: Alpha-Beta Pruning, Beam Search (k=8), Move Ordering


% La direttiva 'module' dice a Prolog il nome di questo file ('ai') 
% e quali funzioni possono essere chiamate (esportate) dagli altri file.
% Arity: calcola_mossa_ai/4 significa che la funzione accetta 4 parametri.
:- module(ai, [calcola_mossa_ai/4, avversario/2]).

% 'use_module' importa le funzioni dagli altri file del nostro progetto.
:- use_module(engine).
:- use_module(kb).
:- use_module(library(random)). % Ci serve per generare numeri casuali

% =========================================================
% 1. ENTRY POINT (Punto di ingresso principale)
% Questa è la funzione che server.pl chiama per far pensare il computer.
% Parametri:
% 1. Pezzi: La lista attuale di tutte le pedine in gioco.
% 2. FazioneAI: Chi sta giocando (attaccante o difensore).
% 3. Profondita: Quanti turni nel futuro vogliamo calcolare (es. 3).
% 4. MossaScelta: La VARIABILE in cui salveremo il risultato finale.
% =========================================================
calcola_mossa_ai(Pezzi, FazioneAI, Profondita, MossaScelta) :-
    
    % PASSO 1: Generazione e Ordinamento
    % Chiamiamo un'altra funzione per trovare tutte le mosse legali.
    % La variabile 'MosseOrdinate' si riempirà con una lista di mosse
    % già classificate dalla migliore alla peggiore.
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    
    % \= significa "diverso da". Controlliamo che la lista non sia vuota ([]).
    % Se fosse vuota, Prolog si fermerebbe qui (fallimento).
    MosseOrdinate \= [], 
    
    % PASSO 2: BEAM SEARCH (Capitolo 10.4 della Dispensa)
    % Il professore spiega che per rendere il problema "trattabile" si selezionano
    % solo i 'k' successori migliori. 
    % Qui k=8. Scartiamo tutte le altre mosse per non sovraccaricare la CPU.
    prendi_primi(8, MosseOrdinate, MosseTop), 
    
    % PASSO 3: FALLBACK MOVE (La mossa salvavita)
    % In Prolog, il simbolo '=' fa "pattern matching" (unificazione).
    % [Testa | Coda] divide una lista. Stiamo estraendo la primissima mossa 
    % da 'MosseTop' e salvando le sue coordinate (FallbackFX, ecc.).
    % Perché? Se l'IA si rende conto che PERDERÀ al 100% qualunque cosa faccia, 
    % la ricerca dell'albero fallisce. Avendo questa mossa di riserva, 
    % l'IA farà comunque un passo (il "meno peggio") invece di crashare il gioco.
    MosseTop = [mossa(FallbackFX, FallbackFY, FallbackTX, FallbackTY, _) | _],
    
    % PASSO 4: Inizializzazione limiti Alpha-Beta
    % L'Alpha-Beta usa una "finestra" di valori.
    % Alpha: il punteggio minimo garantito che l'IA sa di poter ottenere (parte da -100.000).
    % Beta: il punteggio massimo che l'avversario ci concederà (parte da +100.000).
    Alpha = -100000,
    Beta = 100000,
    
    % PASSO 5: Chiamata al ciclo radice.
    % Inizia a valutare le 8 mosse. MossaScelta uscirà da qui con il risultato definitivo.
    valuta_radice(MosseTop, FazioneAI, Profondita, Alpha, Beta, -100000, mossa(FallbackFX, FallbackFY, FallbackTX, FallbackTY), MossaScelta, _Punteggio).


% =========================================================
% 2. MOVE ORDERING (Ordine di Esplorazione - Cap. 11)
% Il prof dice: "L'efficacia della potatura dipende dall'ordine... caso ottimale: i figli migliori esplorati per primi".
% =========================================================
genera_mosse_ordinate(Pezzi, Fazione, MosseOrdinate) :-
    
    % findall/3 è una funzione nativa di Prolog potentissima.
    % Sintassi: findall(Oggetto_da_creare, Obiettivo_da_soddisfare, Lista_risultato).
    findall(
        Score-mossa(FX, FY, TX, TY, NP), % Crea un oggetto composto: Punteggio unito alla mossa con un '-'
        (
            % 1. Trova una mossa valida usando le regole del gioco (motore.pl)
            % NP conterrà la scacchiera *dopo* che la mossa è stata fatta.
            genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NP),
            
            % 2. Fa una stima super-veloce di quanto è buona questa mossa (es. ho mangiato qualcuno?)
            stima_veloce(NP, Fazione, BaseScore),
            
            % 3. Aggiunge un numero casuale da 0 a 5. Questo evita che l'IA giochi
            % sempre l'esatta stessa partita se ripetuta. Crea "varietà" tattica.
            random_between(0, 5, Rand), 
            Score is BaseScore + Rand % 'is' esegue operazioni matematiche in Prolog
        ),
        MosseConScore % Il risultato va in questa variabile
    ),
    
    % keysort/2 prende liste di tipo Chiave-Valore (il nostro Score-mossa)
    % e le ordina. Purtroppo Prolog le ordina in modo CRESCENTE (dal peggio al meglio).
    keysort(MosseConScore, MosseAscendenti),
    
    % reverse/2 inverte la lista. Ora abbiamo le mosse con punteggio più alto IN CIMA.
    reverse(MosseAscendenti, MosseOrdinate).


% --- RICORSIONE IN CODA (Tail Recursion) PER ALTA VELOCITÀ ---
% Prolog non ha cicli "for". Per contare i pezzi si usa la ricorsione. Non si é usato il findall perché è più lento (crea una lista intermedia). 
% Qui invece lavoriamo direttamente sui numeri, senza liste per non sovraccaricare la RAM. 
% Contiamo i nostri pezzi e sottraiamo i pezzi nemici.
stima_veloce(Pezzi, Fazione, Score) :-
    conta_fazione(Pezzi, Fazione, Miei),
    avversario(Fazione, Avv),
    conta_fazione(Pezzi, Avv, Suoi),
    Score is (Miei * 10) - (Suoi * 10). %si moltiplica per 10 per dare più peso alla differenza di pezzi. questo si chiama "Risoluzione" o "Granularità" dell'euristica. 
                                        %se prima di una mossa il randint da un numero alto (5) per una mossa che non mangia nessun pezzo (0)(mossa inutile o poco utile), 
                                        %lo Score is BaseScore + Rand sará alto (0+5) e l'IA preferirá questa mossa a una mossa piu utile (2) ma con Score piu basso se randint da un numero piccolo (0).

                                        %se ia troppo stupida si puo aumentare il peso (Miei * 20) - (Suoi * 20) per dare piu importanza alla differenza di pezzi, e diminuire l'effetto del random (da 0 a 5) che diventa meno influente.

% Caso base: se la lista è vuota ([]), il conteggio è 0.
conta_fazione([], _, 0). %se la lista é vuota ([]) non mi interessa quale fazione sto contando (_), il risultato è 0.

% Caso 1: La testa della lista ([Testa | Coda]) è un pezzo della NOSTRA fazione.
conta_fazione([pezzo(_, Fazione, _, _)|T], Fazione, N) :- % con [pezzo(_, Fazione, _, _) | T] Prolog estrae il primo pezzo. Vede che la Fazione di questo pezzo è esattamente uguale alla Fazione che stiamo cercando di contare. 
    !, %si usa Il Cut (!) per fermarlo perche ha trovato un pezzo e non proverá a leggere la Riga 3. 
conta_fazione(T, Fazione, N1), %Prolog mette da parte il pezzo appena pescato e prende con il resto della coda T "ciclando" per contare quanti pezzi Neri ci sono. Il risultato dei pezzi lo memorizza in una variabile temporanea chiamata N1.
N is N1 + 1. %Quando l'esplorazione del resto della Coda finisce, prendo il totale che ho trovato (N1), aggiungo 1 (il pezzo che avevo in mano io), e il totale definitivo diventa N.



% Caso 2: Se la pedina NON è nostra, il Caso 1 fallisce e si arriva qui.
% Richiama se stessa sulla coda (T) senza fare +1.
conta_fazione([_|T], Fazione, N) :- 
    conta_fazione(T, Fazione, N).

% --- HELPER: BEAM SEARCH ---
% Funzione ricorsiva che estrae solo i primi N elementi da una lista.
prendi_primi(0, _, []) :- !. % Caso base 1: Ne ho presi 0, restituisco lista vuota.
prendi_primi(_, [], []) :- !. % Caso base 2: La lista è finita prima di N, restituisco vuoto.
prendi_primi(N, [_Score-Mossa | T], [Mossa | R]) :- % Scarta lo Score, tiene la Mossa, continua sulla coda.
    N > 0, N1 is N - 1,
    prendi_primi(N1, T, R).


% =========================================================
% 3. IL CUORE DELL'ALPHA-BETA PRUNING (Cap. 11)
% In Prolog, gli algoritmi si dividono spesso in una "radice" che 
% tiene traccia dell'azione compiuta, e un "ciclo interno" che valuta
% solo i punteggi puri.
% =========================================================

% --- CICLO DELLA RADICE ---
% Caso base: la lista delle mosse da valutare è vuota. Restituiamo il ValoreTop trovato finora.
valuta_radice([], _, _, _, _, ValoreTop, MossaTop, MossaTop, ValoreTop).

% Analizziamo una mossa alla volta (estratta con [mossa | Resto])
valuta_radice([mossa(FX, FY, TX, TY, NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreTop, MossaTop, MossaFinale, ValoreFinale) :-
    
    % Lanciamo l'esplorazione futura! 'NP' è la scacchiera DOPO questa mossa.
    % Passiamo il turno all'avversario (TurnoAI = false).
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreAttuale),
    
    % Se il valore di questa mossa è MIGLIORE del massimo storico trovato finora...
    ( ValoreAttuale > ValoreTop ->
        NuovoValoreTop = ValoreAttuale, NuovaMossaTop = mossa(FX, FY, TX, TY)
    ;   % Altrimenti, manteniamo i vecchi valori.
        NuovoValoreTop = ValoreTop, NuovaMossaTop = MossaTop
    ),
    
    % Aggiorniamo Alpha (che tiene traccia del punteggio massimo garantito per noi)
    NuovoAlpha is max(Alpha, NuovoValoreTop),
    
    % IL TAGLIO (PRUNING)
    % Se Alpha diventa maggiore o uguale a Beta, significa che in questo ramo 
    % stiamo ottenendo un punteggio che l'avversario non ci permetterà mai di raggiungere
    % (perché prima sceglierebbe un'altra strada). È inutile continuare a calcolare!
    ( NuovoAlpha >= Beta ->
        MossaFinale = NuovaMossaTop, ValoreFinale = NuovoValoreTop, ! % IL CUT(!) SVUOTA LA RAM
    ;   % Altrimenti, procediamo a valutare la prossima mossa nella lista (Resto)
        valuta_radice(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoValoreTop, NuovaMossaTop, MossaFinale, ValoreFinale)
    ).

% --- ALGORITMO ALPHA-BETA RICORSIVO ---

% CASI TERMINALI (FOGLIE DELL'ALBERO)
% 1. La fazione dell'IA ha vinto in questo scenario futuro. Punteggio immenso.
alphabeta(Pezzi, _, _, _, FazioneAI, _, 100000) :- engine:vittoria(Pezzi, FazioneAI), !.
% 2. L'avversario ha vinto. Punteggio orribile (-100000).
alphabeta(Pezzi, _, _, _, FazioneAI, _, -100000) :- avversario(FazioneAI, Avv), engine:vittoria(Pezzi, Avv), !.

% 3. CUTOFF (Cap. 12.1): Profondità arrivata a 0.
% Non indaghiamo oltre nel futuro. Chiamiamo l'Euristica per dare un voto alla plancia attuale.
alphabeta(Pezzi, 0, _, _, FazioneAI, _, Punteggio) :- !, euristica(Pezzi, FazioneAI, Punteggio).


% NODO MAX: È il turno della nostra IA (TurnoAI = true). L'obiettivo è MASSIMIZZARE.
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, true, PunteggioMassimo) :-
    Profondita > 0,
    genera_mosse_ordinate(Pezzi, FazioneAI, MosseOrdinate),
    prendi_primi(8, MosseOrdinate, Figli), 
    % Se non abbiamo mosse disponibili, siamo bloccati (è una sconfitta)
    ( Figli = [] -> PunteggioMassimo = -100000 
    ; NuovaProf is Profondita - 1, % Scendiamo di un livello nel futuro
      % Chiamiamo la funzione che cicla su questi figli
      valuta_max(Figli, FazioneAI, NuovaProf, Alpha, Beta, -100000, PunteggioMassimo)
    ).

% NODO MIN: È il turno dell'Avversario (TurnoAI = false). L'obiettivo è MINIMIZZARE.
alphabeta(Pezzi, Profondita, Alpha, Beta, FazioneAI, false, PunteggioMinimo) :-
    Profondita > 0,
    avversario(FazioneAI, Nemico),
    % Generiamo le mosse come se fossimo il nemico, per vedere cosa farà
    genera_mosse_ordinate(Pezzi, Nemico, MosseOrdinate),
    prendi_primi(8, MosseOrdinate, Figli), 
    ( Figli = [] -> PunteggioMinimo = 100000 % Se il nemico non ha mosse, noi vinciamo!
    ; NuovaProf is Profondita - 1,
      valuta_min(Figli, FazioneAI, NuovaProf, Alpha, Beta, 100000, PunteggioMinimo)
    ).

% --- Iterazione dei figli per trovare il MASSIMO ---
valuta_max([], _, _, _, _, Valore, Valore). % Lista vuota: restituisce il Valore accumulato
valuta_max([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :- %NP = Nuovi Pezzi (nuova configurazione dopo la mossa)
    % Valuta il figlio passando il turno all'avversario (false)
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, false, ValoreFiglio), %valuta_max dice a alphabeta di andare nel futuro durante il turno nemico (False) e valutare quella configurazione. ValoreFiglio è il punteggio che otteniamo da quella configurazione futura.
    % max/2 tiene il numero più alto
    NuovoMax is max(ValoreAttuale, ValoreFiglio), %compara il ValoreAttuale (quello piu alto momentaneamente) e la convenienza della mossa (ValoreFiglio)
    NuovoAlpha is max(Alpha, NuovoMax), %aggiorna Alpha con il massimo tra il vecchio Alpha e il NuovoMax trovato.
    % TAGLIO BETA: Se Alpha (il nostro min garantito) supera Beta (il max concesso dal nemico)
    ( NuovoAlpha >= Beta -> ValoreFinale = NuovoMax, ! 
    ; valuta_max(Resto, FazioneAI, Prof, NuovoAlpha, Beta, NuovoMax, ValoreFinale)
    ).

% --- Iterazione dei figli per trovare il MINIMO ---
valuta_min([], _, _, _, _, Valore, Valore).
valuta_min([mossa(_,_,_,_,NP) | Resto], FazioneAI, Prof, Alpha, Beta, ValoreAttuale, ValoreFinale) :-
    % Valuta il figlio passando il turno a noi (true)
    alphabeta(NP, Prof, Alpha, Beta, FazioneAI, true, ValoreFiglio),
    % min/2 tiene il numero più basso (quello che fa più male alla nostra IA)
    NuovoMin is min(ValoreAttuale, ValoreFiglio),
    NuovoBeta is min(Beta, NuovoMin),
    % TAGLIO ALPHA
    ( Alpha >= NuovoBeta -> ValoreFinale = NuovoMin, ! 
    ; valuta_min(Resto, FazioneAI, Prof, Alpha, NuovoBeta, NuovoMin, ValoreFinale)
    ).


% =========================================================
% 4. FUNZIONE DI VALUTAZIONE (EURISTICA) - Cap 12.1
% È una formula matematica che dà un voto "umano" a una configurazione.
% =========================================================
euristica(Pezzi, Fazione, Punteggio) :-
    conta_fazione(Pezzi, attaccante, NumAtt),
    conta_fazione(Pezzi, difensore, NumDif),

    % Il pezzo più importante è il Re. Se esiste ancora in plancia, calcoliamo la sua posizione.
    ( member(pezzo(re, difensore, RX, RY), Pezzi) ->
        
        % Distanza di Manhattan ("Geometria del taxi") verso i 4 angoli di fuga (1,1 1,9 9,1 9,9).
        D1 is abs(RX - 1) + abs(RY - 1),
        D2 is abs(RX - 1) + abs(RY - 9),
        D3 is abs(RX - 9) + abs(RY - 1),
        D4 is abs(RX - 9) + abs(RY - 9),
        DistAngolo is min(min(D1, D2), min(D3, D4)),
        
        % Se il Re è a distanza 3 o meno dall'angolo, vuol dire che sta scappando e la partita 
        % sta finendo. Assegniamo un modificatore 'MinacceRe'.
        (DistAngolo < 4 -> MinacceRe = 1 ; MinacceRe = 0)
    ;
        % Se il Re non c'è, mettiamo valori dummy per non far fallire la matematica.
        DistAngolo = 99, MinacceRe = 0
    ),

    % Pesi base: un attaccante vale 100 punti, un difensore 150 (perché sono numericamente di meno).
    ValoreAttaccanti is NumAtt * 100,
    ValoreDifensori is NumDif * 150, 

    % Punteggio asimmetrico: gli obiettivi cambiano a seconda della fazione.
    ( Fazione == attaccante ->
        % L'ATTACCANTE (Jotun) (Neri) vuole:
        % + Tanti propri pezzi, - Pochi pezzi bianchi
        % + Re lontano dagli angoli (DistAngolo Alta = Bonus)
        % - PENALITÀ ESTREMA se il Re è quasi all'angolo (MinacceRe = 1 -> -1000 punti!)
        Punteggio is ValoreAttaccanti - ValoreDifensori + (DistAngolo * 50) - (MinacceRe * 1000)
    ;
        % IL DIFENSORE (Einherjar) (Bianchi) vuole:
        % + Tanti propri pezzi, - Pochi pezzi neri
        % + Re vicino agli angoli (DistAngolo Bassa = Meno penalità)
        % + BONUS ESTREMO se il Re è quasi all'angolo (MinacceRe = 1 -> +1000 punti!)
        Punteggio is ValoreDifensori - ValoreAttaccanti - (DistAngolo * 60) + (MinacceRe * 1000)
    ).

% =========================================================
% 5. UTILITY DI COLLEGAMENTO AL MOTORE (engine.pl)
% =========================================================
% Questo predicato funge da ponte: prende un pezzo, prova le coordinate X, Y
% e verifica con 'engine' se la mossa è fisicamente legale.
genera_mossa_valida(Pezzi, Fazione, FX, FY, TX, TY, NuoviPezzi) :- %FX, FY = From X e From Y; TX, TY = To X e To Y; NuoviPezzi = la configurazione dopo la mossa
    member(pezzo(_Tipo, Fazione, FX, FY), Pezzi), %appena trova un pezzo della fazione in considerazione (ignorando di che tipo sia), salva le sue coordinate in FX e FY. Questo è il pezzo che vogliamo muovere.
    kb:dimensione(Max), %richiama il modulo 'kb' per sapere qual è la dimensione della plancia. Max sarà 9 in questo caso.
    % between genera in loop tutti i numeri da 1 alla grandezza della plancia.
    ( between(1, Max, TX), TX \= FX, TY = FY ; between(1, Max, TY), TY \= FY, TX = FX ), % " , " AND " ; " OR. between(1, Max, TX) genera numeri random tra 1 e max e lo assegna a TX. TX \= FX serve per evitare di generare la stessa coordinata di partenza. TY = FY perché stiamo muovendo in linea retta, quindi una coordinata rimane uguale.
    % Chiama il modulo 'engine' per validare la fisica della mossa.
    engine:mossa_legale(FX, FY, TX, TY, Pezzi),
    engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi).

% Definizione con FACTS delle fazioni.
avversario(difensore, attaccante). %avversario del difensore è l'attaccante
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
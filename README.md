# Hnefatafl: Il Gioco dei Re Vichinghi (Prolog & Web)

Un'implementazione full-stack del celebre gioco da tavolo asimmetrico vichingo, variante **Copenhagen 9x9**. Il progetto utilizza **SWI-Prolog** come motore logico e decisionale (backend) e un'interfaccia **Web HTML/JS/CSS** (frontend) servita nativamente dal server HTTP di Prolog.

Questo progetto esplora l'integrazione tra la Programmazione Logica (rappresentazione della conoscenza, inferenza delle regole) e l'Intelligenza Artificiale classica (ricerca avversaria, euristiche).

---

## 📜 Cenni Storici e Regole del Gioco

L'*Hnefatafl* (scacchiera del Re) appartiene alla famiglia dei giochi *Tafl*, popolari in Scandinavia e nel Nord Europa prima dell'introduzione degli scacchi. È un gioco di strategia puro, caratterizzato da una forte **asimmetria** degli schieramenti e degli obiettivi:

* **I Difensori (Bianchi / Einherjar):** Un gruppo ristretto di soldati (12) che protegge il proprio Re (Odino) situato al centro della plancia, sul Trono.
* **Gli Attaccanti (Neri / Jötunn):** Un contingente numericamente superiore (24) disposto lungo i bordi della scacchiera.

**Condizioni di Vittoria:**
* Il **Difensore** vince se riesce a scortare il Re fino a una delle quattro caselle d'angolo (Fuga).
* L'**Attaccante** vince se riesce a catturare il Re circondandolo (su 4 lati se è sul Trono, su 3 se è adiacente al Trono, su 2 lati - a *sandwich* - in campo aperto).

**Cattura Normale:**
Tutti i pezzi (tranne il Re) si muovono ortogonalmente come la Torre degli scacchi. Un pezzo viene catturato se viene chiuso a "sandwich" tra due pezzi nemici o tra un pezzo nemico e una casella speciale vuota (Trono o Angoli).

---

## 🧠 L'Intelligenza Artificiale: Tecniche Utilizzate

Il "cervello" dell'avversario virtuale (`ai.pl`) è stato progettato per bilanciare tempi di risposta e profondità tattica. Per rendere trattabile l'esplorazione dell'albero di gioco, sono state implementate le seguenti tecniche classiche di Intelligenza Artificiale:

### 1. Minimax con Potatura Alpha-Beta
L'algoritmo centrale è il Minimax, che simula i turni futuri massimizzando il punteggio per la fazione mossa dall'IA e minimizzandolo per l'avversario. Per ottimizzare la ricerca, viene applicato l'**Alpha-Beta Pruning** (`TAGLIO ALPHA` e `TAGLIO BETA`), che interrompe l'esplorazione dei rami dell'albero decisionale quando è matematicamente certo che porteranno a una situazione peggiore di un'alternativa già valutata.

### 2. Move Ordering (Ordinamento delle Mosse)
L'efficienza della potatura Alpha-Beta dipende fortemente dall'ordine in cui vengono valutati i nodi figli. Tramite la funzione `genera_mosse_ordinate/3`, le mosse legali vengono preventivamente classificate con una *stima veloce*. Vengono esplorate per prime le mosse che garantiscono un vantaggio di pezzi (catture), massimizzando le probabilità di innescare tagli (cut-off) fin dai primi cicli della CPU. Per prevenire la ripetitività deterministica, un modificatore pseudocasuale (`random_between`) garantisce varietà tattica a parità di punteggio.

### 3. Beam Search Temporale (k=8)
Dato l'elevato *branching factor* dell'Hnefatafl (ogni pezzo può scorrere lungo righe e colonne vuote, generando centinaia di varianti per turno), esplorare tutte le foglie è impraticabile in tempo reale. È stata introdotta una logica di **Beam Search**: per ogni nodo dell'albero, vengono scartate le mosse palesemente sfavorevoli e si approfondisce la ricerca solo per i *k=8* nodi promettenti (i "Top 8").

### 4. Euristica Asimmetrica e Manhattan Distance
Quando l'algoritmo raggiunge la profondità massima consentita, si affida alla funzione di valutazione `euristica/3`. Poiché il gioco è asimmetrico, l'euristica calcola i punteggi in modo diverso per le due fazioni:
* Viene calcolata la differenza materiale tra i pezzi in plancia (tramite *Tail Recursion* per evitare sovraccarichi sullo stack di memoria).
* Per il **Re**, viene calcolata la **Distanza di Manhattan** ("geometria del taxi") verso gli angoli.
* Se la fuga è imminente (distanza < 4), scattano dei pesi moltiplicatori estremi (± 1000 punti) per innescare un comportamento di aggressione/difesa critica.

---

## 🏛️ Architettura e Moduli del Sistema

Il codice è rigorosamente frammentato seguendo il pattern architetturale, disaccoppiando la rappresentazione dei dati dalla logica e dalla view.

* `kb.pl` (Knowledge Base): Definisce i fatti statici, le dimensioni della griglia (9x9), la posizione del trono e lo stato iniziale dei 37 pezzi.
* `engine.pl` (Logica di Dominio): Verifica la validità ortogonale, l'assenza di ostacoli e applica i pattern fisici di cattura e sandwich. Implementa logiche di Lazy Evaluation per ridurre il calcolo delle adiacenze.
* `ai.pl` (Controller IA): L'albero di ricerca, il Move Ordering, la funzione euristica e le ottimizzazioni di performance in Prolog puro.
* `server.pl` (Web Server & UI): Avvia il demone HTTP nativo sulla porta 8080. Si occupa di renderizzare il DOM fotorealistico e di gestire le code di invio asincrono (`async/await` JavaScript) per garantire transizioni e animazioni fluide disaccoppiate dalla rapidità di calcolo del backend.

---

## 🚀 Prerequisiti e Avvio del Gioco

Il progetto non richiede l'installazione di runtime esterni, Node.js o Apache. Tutto è gestito da SWI-Prolog.

1. Installare **SWI-Prolog** sulla propria macchina.
2. Posizionarsi nella directory del progetto.
3. Avviare la shell Prolog caricando il modulo server:
   ```bash
   swipl -s server.pl
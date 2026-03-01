# Hnefatafl-Prolog: A Logic-Based AI Engine 🛡️♔

Benvenuti nel progetto **Hnefatafl-Prolog**, un'implementazione avanzata in **SWI-Prolog** del celebre gioco da tavolo vichingo nella variante **Tablut 9x9** (secondo le ricostruzioni storiche di Linneo, 1732).

Questo progetto non è un semplice "compitino", ma un esercizio di **Ingegneria del Software Logico**, progettato con un'architettura modulare e un motore di inferenza trasparente.



## 🎯 Obiettivi del Progetto
L'obiettivo è dimostrare la potenza del linguaggio Prolog nella risoluzione di problemi di:
- **Ricerca nello spazio degli stati**: Implementazione di algoritmi Minimax con Alpha-Beta Pruning.
- **Sistemi Esperti**: Un motore di regole deterministico per la gestione delle catture asimmetriche.
- **Separazione delle Competenze**: Architettura modulare (KB, Engine, UI, AI).

## 🏗️ Architettura del Software
Il sistema è diviso in moduli indipendenti per garantire testabilità e manutenibilità:
- `kb.pl`: Rappresentazione dello stato e della conoscenza iniziale.
- `engine.pl`: Logica di movimento (tipo torre) e regole di cattura a "sandwich".
- `ui.pl`: Interfaccia utente TUI (Text User Interface) con supporto colori ANSI e simboli Unicode.
- `ia.pl`: Il cervello dell'avversario virtuale basato su euristiche di mobilità e sicurezza del Re.
- `main.pl`: Punto d'ingresso e loop principale di gioco.

## 🚀 Come Eseguire il Progetto
1. Assicurati di avere installato [SWI-Prolog](https://www.swi-prolog.org/).
2. Clona il repository o scarica i file.
3. Avvia SWI-Prolog e consulta il file `main.pl`:
   ```prolog
   ?- [main].
% =========================================================
% MODULO: server.pl (DASHBOARD WEB DEFINITIVA E PULITA)
% =========================================================

:- module(server, [avvia_server/0, ferma_server/0, resetta_partita/0]).
:- encoding(utf8).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(kb).
:- use_module(engine).
:- use_module(ai).

% --- STATO DEL GIOCO IN MEMORIA ---
:- dynamic stato_corrente/1.

% --- ROTTE DEL SERVER ---
:- http_handler(root(.), pagina_principale, []).
:- http_handler(root(muovi), gestisci_mossa, []).
:- http_handler(root(mossa_ai), gestisci_mossa_ai, []).

% --- AVVIO E RESET ---
avvia_server :-
    resetta_partita,
    http_server(http_dispatch, [port(8080)]),
    writeln('🚀 SERVER WEB AVVIATO CON SUCCESSO!'),
    writeln('👉 Vai su: http://localhost:8080').

ferma_server :-
    http_stop_server(8080, _),
    writeln('🛑 Server fermato.').

resetta_partita :-
    kb:stato_iniziale(Pezzi),
    retractall(stato_corrente(_)),
    assertz(stato_corrente(Pezzi)).

% --- GENERAZIONE HTML DELLA PAGINA ---
pagina_principale(_Request) :-
    stato_corrente(Pezzi),
    reply_html_page(
        title('Hnefatafl - Prolog Engine'),
        [
            style('body { background-color: #2c1e16; color: #f5deb3; font-family: "Segoe UI", sans-serif; user-select: none; }'),
            h1([style('text-align: center; margin-top: 30px; letter-spacing: 2px;')], 'HNEFATAFL ᛟ TABLUT'),
            
            % I Bottoni dell'AI
            div([style('text-align: center; margin-bottom: 20px;')], [
                button([onclick('faiMossaAI("attaccante")'), style('background-color: #8b0000; color: white; border: 2px solid gold; padding: 10px 20px; margin: 10px; font-size: 16px; cursor: pointer; font-weight: bold;')], 'Fai giocare l\'AI (Rossi ᚦ)'),
                button([onclick('faiMossaAI("difensore")'), style('background-color: #5d4037; color: white; border: 2px solid gold; padding: 10px 20px; margin: 10px; font-size: 16px; cursor: pointer; font-weight: bold;')], 'Fai giocare l\'AI (Bianchi ᛏ)')
            ]),
            
            % La Scacchiera
            div([style('display: flex; justify-content: center;')],
                \renderizza_scacchiera(Pezzi)
            ),
            
            % Script JavaScript (Integrato in modo sicuro)
            html(script(type('text/javascript'), '
                let selX = null, selY = null;

                function clicca(x, y) {
                    let id = "c_" + x + "_" + y;
                    let cella = document.getElementById(id);
                    let contenutoCella = cella.innerText.trim();
                    let isPezzo = (contenutoCella === "ᛟ" || contenutoCella === "ᛏ" || contenutoCella === "ᚦ");

                    if (selX === null) {
                        if (isPezzo) {
                            selX = x; selY = y;
                            cella.style.boxShadow = "inset 0 0 0 5px #ffd700";
                        }
                    } else {
                        if (selX === x && selY === y) {
                            cella.style.boxShadow = "none";
                            selX = null; selY = null;
                        } else if (isPezzo) {
                            document.getElementById("c_" + selX + "_" + selY).style.boxShadow = "none";
                            selX = x; selY = y;
                            cella.style.boxShadow = "inset 0 0 0 5px #ffd700";
                        } else {
                            let oldX = selX; let oldY = selY;
                            let vecchiaCella = document.getElementById("c_" + oldX + "_" + oldY);
                            selX = null; selY = null; 
                            
                            fetch("/muovi?fx=" + oldX + "&fy=" + oldY + "&tx=" + x + "&ty=" + y)
                            .then(response => response.text())
                            .then(risultato => {
                                if (risultato === "ok") {
                                    window.location.reload(); 
                                } else {
                                    if(vecchiaCella) vecchiaCella.style.boxShadow = "none";
                                    cella.style.backgroundColor = "#ff4c4c"; 
                                    setTimeout(() => { window.location.reload(); }, 300);
                                }
                            });
                        }
                    }
                }

                function faiMossaAI(fazione) {
                    document.body.style.cursor = "wait"; 
                    fetch("/mossa_ai?fazione=" + fazione)
                    .then(response => response.text())
                    .then(risultato => {
                        if (risultato === "ok") {
                            window.location.reload();
                        } else {
                            alert("L\'AI non ha trovato mosse valide o la partita è finita!");
                            document.body.style.cursor = "default";
                        }
                    });
                }
            '))
        ]
    ).

% --- RENDER DELLA SCACCHIERA ---
renderizza_scacchiera(Pezzi) -->
    { kb:dimensione(N) },
    html(table([style('border-collapse: collapse; border: 12px solid #3e2723; box-shadow: 0px 15px 30px rgba(0,0,0,0.8); background-color: #8b5a2b;')],
        \righe_scacchiera(1, N, Pezzi)
    )).

righe_scacchiera(Y, MaxY, _) --> { Y > MaxY }, !.
righe_scacchiera(Y, MaxY, Pezzi) -->
    html(tr(\celle_scacchiera(1, Y, MaxY, Pezzi))),
    { NextY is Y + 1 },
    righe_scacchiera(NextY, MaxY, Pezzi).

celle_scacchiera(X, _, MaxX, _) --> { X > MaxX }, !.
celle_scacchiera(X, Y, MaxX, Pezzi) -->
    { determina_simbolo_web(X, Y, Pezzi, Simbolo, ColoreSfondo, ColoreTesto),
      format(string(IdCella), "c_~w_~w", [X, Y]),
      format(string(AzioneClick), "clicca(~w, ~w)", [X, Y]),
      format(string(StileCss), "width: 65px; height: 65px; text-align: center; vertical-align: middle; font-size: 36px; font-weight: bold; border: 2px solid #5c4033; cursor: pointer; background-color: ~w; color: ~w; transition: background-color 0.2s, box-shadow 0.2s;", [ColoreSfondo, ColoreTesto])
    },
    html(td([id(IdCella), onclick(AzioneClick), style(StileCss)], Simbolo)),
    { NextX is X + 1 },
    celle_scacchiera(NextX, Y, MaxX, Pezzi).

% --- LOGICA VISIVA (Colori e Rune) ---
determina_simbolo_web(X, Y, Pezzi, 'ᛟ', '#4e342e', '#ffd700') :- member(pezzo(re, _, X, Y), Pezzi), !.
determina_simbolo_web(X, Y, Pezzi, 'ᛏ', '#5d4037', '#fffaea') :- member(pezzo(_, difensore, X, Y), Pezzi), !.
determina_simbolo_web(X, Y, Pezzi, 'ᚦ', '#8b0000', '#1a1a1a') :- member(pezzo(_, attaccante, X, Y), Pezzi), !.
determina_simbolo_web(X, Y, _, 'ᛝ', '#556b2f', '#a9a9a9')     :- kb:trono(X, Y), !.
determina_simbolo_web(X, Y, _, 'ᚠ', '#556b2f', '#8fbc8f')     :- kb:dimensione(N), ( (X=1, Y=1) ; (X=1, Y=N) ; (X=N, Y=1) ; (X=N, Y=N) ), !.
determina_simbolo_web(X, Y, _, '', Sfondo, '')                 :- ( 0 =:= (X+Y) mod 2 -> Sfondo = '#d2b48c' ; Sfondo = '#cdaa7d' ).

% --- API BACKEND (Gestione delle mosse) ---
gestisci_mossa(Request) :-
    http_parameters(Request, [fx(FX, [integer]), fy(FY, [integer]), tx(TX, [integer]), ty(TY, [integer])]),
    stato_corrente(Pezzi),
    ( engine:mossa_legale(FX, FY, TX, TY, Pezzi) ->
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)),
        assertz(stato_corrente(NuoviPezzi)),
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            format('Content-type: text/plain~n~nvittoria_~w', [Vincitore])
        ;   format('Content-type: text/plain~n~nok')
        )
    ;   format('Content-type: text/plain~n~nko')
    ).

% --- API BACKEND (Gestione dell'AI) ---
gestisci_mossa_ai(Request) :-
    http_parameters(Request, [fazione(FazioneString, [string])]),
    atom_string(FazioneAI, FazioneString),
    stato_corrente(Pezzi),
    ( ai:calcola_mossa_ai(Pezzi, FazioneAI, 1, mossa(FX, FY, TX, TY)) ->
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)),
        assertz(stato_corrente(NuoviPezzi)),
        format('Content-type: text/plain~n~nok')
    ;   format('Content-type: text/plain~n~nko')
    ).

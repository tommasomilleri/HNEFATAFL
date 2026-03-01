% =========================================================
% MODULO: server.pl (DASHBOARD WEB - EDIZIONE PREMIUM 3D)
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

% --- STATO DEL GIOCO IN MEMORIA (Macchina a Stati) ---
:- dynamic stato_corrente/1.
:- dynamic ruolo_umano/1.  % 'sconosciuto', 'attaccante', 'difensore'
:- dynamic ruolo_ai/1.     % 'sconosciuto', 'attaccante', 'difensore'
:- dynamic stato_gioco/1.  % 'turno_umano', 'calcolo_ai', 'vittoria_attaccante', 'vittoria_difensore'

% --- ROTTE DEL SERVER ---
:- http_handler(root(.), pagina_principale, []).
:- http_handler(root(muovi), gestisci_mossa, []).
:- http_handler(root(trigger_ai), esegui_mossa_ai, []).
:- http_handler(root(reset), gestisci_reset, []).

% --- AVVIO E RESET ---
avvia_server :-
    resetta_partita,
    http_server(http_dispatch, [port(8080)]),
    writeln('🚀 SERVER WEB 3D AVVIATO CON SUCCESSO!'),
    writeln('👉 Vai su: http://localhost:8080').

ferma_server :-
    http_stop_server(8080, _),
    writeln('🛑 Server fermato.').

resetta_partita :-
    kb:stato_iniziale(Pezzi),
    retractall(stato_corrente(_)), assertz(stato_corrente(Pezzi)),
    retractall(ruolo_umano(_)),    assertz(ruolo_umano(sconosciuto)),
    retractall(ruolo_ai(_)),       assertz(ruolo_ai(sconosciuto)),
    retractall(stato_gioco(_)),    assertz(stato_gioco(turno_umano)).

gestisci_reset(_Request) :-
    resetta_partita,
    format('Content-type: text/plain~n~nok').

% --- GENERAZIONE HTML DELLA PAGINA ---
pagina_principale(_Request) :-
    stato_corrente(Pezzi),
    stato_gioco(StatoGioco),
    reply_html_page(
        title('Hnefatafl - Edizione Premium'),
        [
            style('
                body { 
                    background-color: #1a120b; 
                    color: #f5deb3; 
                    font-family: "Segoe UI", serif; 
                    text-align: center; 
                    user-select: none;
                    background-image: radial-gradient(#2c1e16 2px, transparent 2px);
                    background-size: 30px 30px;
                }
                @keyframes pulse { 0% { opacity: 1; transform: scale(1); } 50% { opacity: 0.8; transform: scale(1.02); } 100% { opacity: 1; transform: scale(1); } }
                .banner-ai { background: linear-gradient(145deg, #3e2723, #1a120b); color: #ffd700; padding: 12px 30px; border-radius: 50px; width: fit-content; margin: 0 auto 20px auto; font-size: 18px; font-weight: bold; border: 1px solid #ffd700; animation: pulse 1.5s infinite; box-shadow: 0 10px 20px rgba(0,0,0,0.8); text-transform: uppercase; letter-spacing: 2px; }
                .banner-win { background: linear-gradient(145deg, #556b2f, #2e3b19); color: white; padding: 15px 40px; border-radius: 8px; width: fit-content; margin: 0 auto 20px auto; font-size: 20px; font-weight: bold; border: 2px solid #ffd700; box-shadow: 0 10px 20px rgba(0,0,0,0.8); }
                .banner-loss { background: linear-gradient(145deg, #8b0000, #4a0000); color: white; padding: 15px 40px; border-radius: 8px; width: fit-content; margin: 0 auto 20px auto; font-size: 20px; font-weight: bold; border: 2px solid #ffd700; box-shadow: 0 10px 20px rgba(0,0,0,0.8); }
                .btn-reset { background-color: #1a1a1a; color: #8fbc8f; border: 1px solid #8fbc8f; padding: 8px 20px; border-radius: 4px; cursor: pointer; transition: 0.2s; margin-top: 10px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;}
                .btn-reset:hover { background-color: #8fbc8f; color: #1a1a1a; box-shadow: 0 0 15px rgba(143, 188, 143, 0.5); }
                table { border-collapse: separate; border-spacing: 4px; border: 16px solid #2b1a10; border-radius: 12px; box-shadow: 0px 25px 50px rgba(0,0,0,0.9), inset 0 0 30px rgba(0,0,0,0.8); background-color: #4e342e; margin: auto; }
            '),
            
            h1([style('margin-top: 20px; letter-spacing: 3px; margin-bottom: 5px; text-shadow: 2px 2px 4px #000;')], 'HNEFATAFL ᛟ TABLUT'),
            button([class('btn-reset'), onclick('fetch("/reset").then(()=>window.location.reload())')], 'Ricomincia Partita'),
            div([style('height: 25px;')], ''),
            
            \banner_stato(StatoGioco),
            
            div([style('display: flex; justify-content: center; padding-bottom: 50px;')],
                \renderizza_scacchiera(Pezzi)
            ),
            
            \script_javascript(StatoGioco)
        ]
    ).

% --- GENERAZIONE BANNER DI STATO ---
banner_stato(calcolo_ai) --> html(div([class('banner-ai')], '⏳ Il Nemico sta studiando le Rune...')).
banner_stato(vittoria_attaccante) --> html(div([class('banner-loss')], '💀 VITTORIA! I Rossi hanno schiacciato il Re!')).
banner_stato(vittoria_difensore) --> html(div([class('banner-win')], '👑 VITTORIA! Il Re Bianco e fuggito!')).
banner_stato(_) --> html(div([style('height: 48px; margin-bottom: 20px;')], '')).

% --- JAVASCRIPT FRONTEND ---
script_javascript(StatoGioco) -->
    { format(string(StatoStr), "~w", [StatoGioco]) },
    html(script(type('text/javascript'), [
        'let statoGioco = "', StatoStr, '";\n',
        'let selX = null, selY = null;\n\n',
        
        'function clicca(x, y) {\n',
        '    if (statoGioco !== "turno_umano") return; \n',
        '    let id = "c_" + x + "_" + y;\n',
        '    let cella = document.getElementById(id);\n',
        '    let contenutoCella = cella.innerText.trim();\n',
        '    let isPezzo = (contenutoCella === "ᛟ" || contenutoCella === "ᛏ" || contenutoCella === "ᚦ");\n\n',

        '    if (selX === null) {\n',
        '        if (isPezzo) { selX = x; selY = y; cella.style.outline = "4px solid #00ffcc"; cella.style.outlineOffset = "-4px"; }\n',
        '    } else {\n',
        '        if (selX === x && selY === y) {\n',
        '            cella.style.outline = "none"; selX = null; selY = null;\n',
        '        } else if (isPezzo) {\n',
        '            document.getElementById("c_" + selX + "_" + selY).style.outline = "none";\n',
        '            selX = x; selY = y; cella.style.outline = "4px solid #00ffcc"; cella.style.outlineOffset = "-4px";\n',
        '        } else {\n',
        '            let oldX = selX; let oldY = selY;\n',
        '            let vecchiaCella = document.getElementById("c_" + oldX + "_" + oldY);\n',
        '            selX = null; selY = null;\n',
        '            fetch("/muovi?fx=" + oldX + "&fy=" + oldY + "&tx=" + x + "&ty=" + y)\n',
        '            .then(response => response.text())\n',
        '            .then(risultato => {\n',
        '                if (risultato === "ok") { window.location.reload(); }\n',
        '                else {\n',
        '                    if(vecchiaCella) vecchiaCella.style.outline = "none";\n',
        '                    cella.style.outline = "4px solid #ff4c4c"; cella.style.outlineOffset = "-4px";\n',
        '                    setTimeout(() => { window.location.reload(); }, 300);\n',
        '                }\n',
        '            });\n',
        '        }\n',
        '    }\n',
        '}\n\n',

        'if (statoGioco === "calcolo_ai") {\n',
        '    setTimeout(() => {\n',
        '        fetch("/trigger_ai").then(response => response.text()).then(res => { window.location.reload(); });\n',
        '    }, 300);\n',
        '}\n'
    ])).

% --- RENDER DELLA SCACCHIERA ---
renderizza_scacchiera(Pezzi) -->
    { kb:dimensione(N) },
    html(table(
        \righe_scacchiera(1, N, Pezzi)
    )).

righe_scacchiera(Y, MaxY, _) --> { Y > MaxY }, !.
righe_scacchiera(Y, MaxY, Pezzi) -->
    html(tr(\celle_scacchiera(1, Y, MaxY, Pezzi))), { NextY is Y + 1 }, righe_scacchiera(NextY, MaxY, Pezzi).

celle_scacchiera(X, _, MaxX, _) --> { X > MaxX }, !.
celle_scacchiera(X, Y, MaxX, Pezzi) -->
    { determina_simbolo_web(X, Y, Pezzi, Simbolo, Sfondo, ColoreTesto, Ombra, Transform),
      format(string(IdCella), "c_~w_~w", [X, Y]),
      format(string(AzioneClick), "clicca(~w, ~w)", [X, Y]),
      % Iniezione dello stile Premium 3D
      format(string(StileCss), "width: 65px; height: 65px; text-align: center; vertical-align: middle; font-size: 38px; font-weight: bold; border-radius: 8px; cursor: pointer; background: ~w; color: ~w; box-shadow: ~w; transform: ~w; text-shadow: 1px 1px 2px rgba(0,0,0,0.8); transition: all 0.2s ease-in-out;", [Sfondo, ColoreTesto, Ombra, Transform])
    },
    html(td([id(IdCella), onclick(AzioneClick), style(StileCss)], Simbolo)),
    { NextX is X + 1 }, celle_scacchiera(NextX, Y, MaxX, Pezzi).

% --- LOGICA VISIVA 3D (Materiali e Altitudini) ---
% Re (Tassello Oro Massiccio)
determina_simbolo_web(X, Y, Pezzi, 'ᛟ', 'radial-gradient(circle, #ffd700 0%, #b8860b 100%)', '#1a120b', '0 6px 0 #8b6508, 0 10px 15px rgba(0,0,0,0.8)', 'translateY(-6px)') :- member(pezzo(re, _, X, Y), Pezzi), !.

% Difensori (Tasselli Avorio/Osso scolpito)
determina_simbolo_web(X, Y, Pezzi, 'ᛏ', 'radial-gradient(circle, #fffaf0 0%, #d7ccc8 100%)', '#3e2723', '0 5px 0 #8d6e63, 0 8px 12px rgba(0,0,0,0.7)', 'translateY(-5px)') :- member(pezzo(_, difensore, X, Y), Pezzi), !.

% Attaccanti (Tasselli Ossidiana/Pietra Lavica)
determina_simbolo_web(X, Y, Pezzi, 'ᚦ', 'radial-gradient(circle, #5c0000 0%, #2a0000 100%)', '#f5deb3', '0 5px 0 #1a0000, 0 8px 12px rgba(0,0,0,0.7)', 'translateY(-5px)') :- member(pezzo(_, attaccante, X, Y), Pezzi), !.

% Trono (Incavato verde muschio)
determina_simbolo_web(X, Y, _, 'ᛝ', '#2e3b19', '#8fbc8f', 'inset 0 4px 10px rgba(0,0,0,0.8)', 'none') :- kb:trono(X, Y), !.

% Angoli (Incavati)
determina_simbolo_web(X, Y, _, 'ᚠ', '#2e3b19', '#8fbc8f', 'inset 0 4px 10px rgba(0,0,0,0.8)', 'none') :- kb:dimensione(N), ( (X=1, Y=1) ; (X=1, Y=N) ; (X=N, Y=1) ; (X=N, Y=N) ), !.

% Caselle Vuote (Legno chiaro/scuro incavato)
determina_simbolo_web(X, Y, _, '', Sfondo, '', 'inset 0 3px 6px rgba(0,0,0,0.5)', 'none') :- 
    ( 0 =:= (X+Y) mod 2 -> Sfondo = '#a67c52' ; Sfondo = '#8b5a2b' ).

% --- API BACKEND (Mossa dell'Utente) ---
gestisci_mossa(Request) :-
    http_parameters(Request, [fx(FX, [integer]), fy(FY, [integer]), tx(TX, [integer]), ty(TY, [integer])]),
    stato_corrente(Pezzi),
    stato_gioco(turno_umano), 
    member(pezzo(_, FazioneMossa, FX, FY), Pezzi),
    ruolo_umano(RuoloAttuale),
    ( RuoloAttuale = sconosciuto ; RuoloAttuale = FazioneMossa ), 
    
    ( engine:mossa_legale(FX, FY, TX, TY, Pezzi) ->
        imposta_ruoli_se_necessario(FazioneMossa), 
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
            retractall(stato_gioco(_)), assertz(stato_gioco(V))
        ;   
            retractall(stato_gioco(_)), assertz(stato_gioco(calcolo_ai))
        ),
        format('Content-type: text/plain~n~nok')
    ;   
        format('Content-type: text/plain~n~nko')
    ).

imposta_ruoli_se_necessario(FazioneMossa) :-
    ruolo_umano(sconosciuto), !,
    retractall(ruolo_umano(_)), assertz(ruolo_umano(FazioneMossa)),
    ai:avversario(FazioneMossa, Avv),
    retractall(ruolo_ai(_)), assertz(ruolo_ai(Avv)).
imposta_ruoli_se_necessario(_).

% --- API BACKEND (Auto-Mossa del Nemico) ---
esegui_mossa_ai(_Request) :-
    stato_corrente(Pezzi),
    stato_gioco(calcolo_ai),
    ruolo_ai(FazioneAI),
    ( ai:calcola_mossa_ai(Pezzi, FazioneAI, 1, mossa(FX, FY, TX, TY)) ->
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
            retractall(stato_gioco(_)), assertz(stato_gioco(V))
        ;
            retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano))
        ),
        format('Content-type: text/plain~n~nok')
    ;   
        retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)),
        format('Content-type: text/plain~n~nko_nessuna_mossa')
    ).
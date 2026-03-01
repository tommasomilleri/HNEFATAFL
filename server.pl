% =========================================================
% MODULO: server.pl (DASHBOARD WEB - DIORAMA 3D INTERATTIVO)
% =========================================================

:- module(server, [avvia_server/0, ferma_server/0, resetta_partita/0]).
:- encoding(utf8).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(library(www_browser)). 
:- use_module(kb).
:- use_module(engine).
:- use_module(ai).

:- dynamic stato_corrente/1, ruolo_umano/1, ruolo_ai/1, stato_gioco/1.

:- http_handler(root(.), pagina_principale, []).
:- http_handler(root(muovi), gestisci_mossa, []).
:- http_handler(root(trigger_ai), esegui_mossa_ai, []).
:- http_handler(root(reset), gestisci_reset, []).

avvia_server :-
    resetta_partita,
    http_server(http_dispatch, [port(8080)]),
    writeln('==========================================='),
    writeln('🚀 MOTORE HNEFATAFL 3D AVVIATO CON SUCCESSO!'),
    writeln('👉 Il browser si sta aprendo automaticamente...'),
    writeln('🔗 (Link manuale: http://localhost:8080 )'),
    writeln('==========================================='),
    catch(www_open_url('http://localhost:8080'), _, true).

ferma_server :- http_stop_server(8080, _), writeln('🛑 Server fermato.').

resetta_partita :-
    kb:stato_iniziale(Pezzi),
    retractall(stato_corrente(_)), assertz(stato_corrente(Pezzi)),
    retractall(ruolo_umano(_)),    assertz(ruolo_umano(sconosciuto)),
    retractall(ruolo_ai(_)),       assertz(ruolo_ai(sconosciuto)),
    retractall(stato_gioco(_)),    assertz(stato_gioco(turno_umano)).

gestisci_reset(_Request) :- resetta_partita, format('Content-type: text/plain~n~nok').

pagina_principale(_Request) :-
    stato_corrente(Pezzi), stato_gioco(StatoGioco),
    reply_html_page(
        title('Hnefatafl - Diorama 3D'),
        [
            style('
                body { background-color: #15100a; color: #f5deb3; font-family: "Segoe UI", serif; text-align: center; user-select: none; background-image: radial-gradient(#2c1e16 2px, transparent 2px); background-size: 30px 30px; margin: 0; padding-top: 10px; overflow-x: hidden; }
                @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.8; } 100% { opacity: 1; } }
                .banner-ai { background: linear-gradient(145deg, #3e2723, #1a120b); color: #ffd700; padding: 12px 30px; border-radius: 50px; width: fit-content; margin: 0 auto 15px auto; font-size: 18px; font-weight: bold; border: 1px solid #ffd700; animation: pulse 1.5s infinite; box-shadow: 0 10px 20px rgba(0,0,0,0.8); text-transform: uppercase; letter-spacing: 2px; }
                .banner-win { background: linear-gradient(145deg, #556b2f, #2e3b19); color: white; padding: 15px 40px; border-radius: 8px; width: fit-content; margin: 0 auto 15px auto; font-size: 20px; font-weight: bold; border: 2px solid #ffd700; box-shadow: 0 10px 20px rgba(0,0,0,0.8); }
                .banner-loss { background: linear-gradient(145deg, #8b0000, #4a0000); color: white; padding: 15px 40px; border-radius: 8px; width: fit-content; margin: 0 auto 15px auto; font-size: 20px; font-weight: bold; border: 2px solid #ffd700; box-shadow: 0 10px 20px rgba(0,0,0,0.8); }
                .btn-reset { background-color: #1a1a1a; color: #8fbc8f; border: 1px solid #8fbc8f; padding: 6px 15px; border-radius: 4px; cursor: pointer; transition: 0.2s; margin-top: 5px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;}
                .btn-reset:hover { background-color: #8fbc8f; color: #1a1a1a; box-shadow: 0 0 15px rgba(143, 188, 143, 0.5); }
                
                table { border-collapse: collapse; border: 18px solid #24140a; border-radius: 12px; box-shadow: 0px 30px 60px rgba(0,0,0,0.95), inset 0 0 40px rgba(0,0,0,0.9); margin: auto; background-color: #3e2723; }
                .board-cell { width: 70px; height: 70px; text-align: center; vertical-align: middle; padding: 0; position: relative; border: 1px solid rgba(0,0,0,0.3); }
                .board-cell.light { background-color: #a67c52; box-shadow: inset 0 3px 6px rgba(0,0,0,0.5); }
                .board-cell.dark { background-color: #8b5a2b; box-shadow: inset 0 3px 6px rgba(0,0,0,0.6); }
                .board-cell.throne { background-color: #2e3b19; box-shadow: inset 0 5px 15px rgba(0,0,0,0.8); }
                .board-cell.corner { background-color: #2e3b19; box-shadow: inset 0 5px 15px rgba(0,0,0,0.8); }
                .board-cell.corner::after { content: "ᚠ"; color: rgba(143,188,143,0.25); font-size: 40px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none;}
                .board-cell.throne::after { content: "ᛝ"; color: rgba(169,169,169,0.3); font-size: 40px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none;}

                /* Highlight mosse legali */
                .valid-move { box-shadow: inset 0 0 25px rgba(0, 255, 204, 0.6) !important; cursor: pointer; }

                /* Pedine Base */
                .piece { width: 50px; height: 50px; border-radius: 50%; margin: 0 auto; transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: bold; position: relative; z-index: 10; cursor: pointer; pointer-events: none; }
                .board-cell > .piece { pointer-events: auto; } /* Solo i pezzi nella griglia prendono click */
                
                .piece.attaccante { background: radial-gradient(circle at 35% 35%, #7a2020, #3a0000); box-shadow: 0 8px 0 #1a0000, 0 12px 10px rgba(0,0,0,0.7); color: #ffb3b3; text-shadow: 1px 1px 2px rgba(0,0,0,0.8); transform: translateY(-4px); }
                .piece.difensore { background: radial-gradient(circle at 35% 35%, #fffaf0, #d7ccc8); box-shadow: 0 8px 0 #8d6e63, 0 12px 10px rgba(0,0,0,0.7); color: #3e2723; text-shadow: 1px 1px 1px rgba(255,255,255,0.6); transform: translateY(-4px); }
                .piece.re { width: 56px; height: 56px; font-size: 32px; background: radial-gradient(circle at 35% 35%, #ffd700, #b8860b); box-shadow: 0 12px 0 #6b4c06, 0 16px 15px rgba(0,0,0,0.8); color: #3e2723; transform: translateY(-6px); }

                /* Fantasma Volante (Segue il mouse) */
                .floating-ghost { position: absolute !important; z-index: 9999 !important; pointer-events: none !important; transition: left 0.1s linear, top 0.1s linear, transform 0.2s; transform: scale(1.2) translateY(-15px) !important; }
                .floating-ghost.attaccante { box-shadow: 0 8px 0 #1a0000, 0 40px 20px rgba(0,0,0,0.5), 0 0 20px rgba(255,100,100,0.5) !important; }
                .floating-ghost.difensore { box-shadow: 0 8px 0 #8d6e63, 0 40px 20px rgba(0,0,0,0.5), 0 0 20px rgba(255,255,255,0.5) !important; }
                .floating-ghost.re { box-shadow: 0 12px 0 #6b4c06, 0 45px 25px rgba(0,0,0,0.5), 0 0 25px rgba(255,215,0,0.7) !important; }

                .dropping { transform: translateY(0) scale(1) !important; box-shadow: 0 2px 0 rgba(0,0,0,0.5), 0 4px 5px rgba(0,0,0,0.8) !important; transition: all 0.2s ease-in !important; z-index: 10; }
            '),
            h1([style('margin-top: 15px; letter-spacing: 3px; margin-bottom: 5px; text-shadow: 2px 2px 4px #000;')], 'HNEFATAFL ᛟ TABLUT'),
            button([class('btn-reset'), onclick('fetch("/reset").then(()=>window.location.reload())')], 'Ricomincia Partita'),
            div([style('height: 15px;')], ''),
            \banner_stato(StatoGioco),
            div([style('display: flex; justify-content: center; padding-bottom: 40px;')], \renderizza_scacchiera(Pezzi)),
            \script_javascript(StatoGioco)
        ]
    ).

banner_stato(calcolo_ai) --> html(div([class('banner-ai')], '⏳ Il Nemico sta studiando le Rune...')).
banner_stato(vittoria_attaccante) --> html(div([class('banner-loss')], '💀 VITTORIA! I Rossi hanno schiacciato il Re!')).
banner_stato(vittoria_difensore) --> html(div([class('banner-win')], '👑 VITTORIA! Il Re Bianco è fuggito!')).
banner_stato(_) --> html(div([style('height: 48px; margin-bottom: 15px;')], '')).

% --- JAVASCRIPT FRONTEND ANIMATO ---
script_javascript(StatoGioco) -->
    { format(string(StatoStr), "~w", [StatoGioco]) },
    html(script(type('text/javascript'), [
        'let statoGioco = "', StatoStr, '";\n',
        'let selX = null, selY = null;\n',
        'let ghostPiece = null;\n',
        'let validMoves = [];\n',
        'let isKing = false;\n\n',
        
        'function getValidMoves(sx, sy) {\n',
        '    let valid = [];\n',
        '    let dirs = [[0,-1], [0,1], [-1,0], [1,0]];\n',
        '    for(let d of dirs) {\n',
        '        let cx = sx + d[0]; let cy = sy + d[1];\n',
        '        while(cx >= 1 && cx <= 9 && cy >= 1 && cy <= 9) {\n',
        '            let cell = document.getElementById("c_" + cx + "_" + cy);\n',
        '            if (cell.querySelector(".piece")) break; \n',
        '            if (!isKing && (cell.classList.contains("corner") || cell.classList.contains("throne"))) break; \n',
        '            valid.push(cx + "_" + cy);\n',
        '            cx += d[0]; cy += d[1];\n',
        '        }\n',
        '    }\n',
        '    return valid;\n',
        '}\n\n',

        'document.addEventListener("mousemove", (e) => {\n',
        '    if (ghostPiece) {\n',
        '        let hovered = document.elementFromPoint(e.clientX, e.clientY);\n',
        '        if (hovered && hovered.tagName === "TD" && hovered.classList.contains("valid-move")) {\n',
        '            let rect = hovered.getBoundingClientRect();\n',
        '            let offset = isKing ? 28 : 25;\n',
        '            ghostPiece.style.left = (rect.left + rect.width/2 - offset) + "px";\n',
        '            ghostPiece.style.top = (rect.top + rect.height/2 - offset - 15) + "px";\n',
        '        } else {\n',
        '            let offset = isKing ? 28 : 25;\n',
        '            ghostPiece.style.left = (e.pageX - offset) + "px";\n',
        '            ghostPiece.style.top = (e.pageY - offset - 15) + "px";\n',
        '        }\n',
        '    }\n',
        '});\n\n',

        'function clicca(x, y, event) {\n',
        '    if (statoGioco !== "turno_umano") return;\n',
        '    let cell = document.getElementById("c_" + x + "_" + y);\n',
        '    let piece = cell.querySelector(".piece");\n',

        '    if (selX === null) {\n',
        '        if (piece) {\n',
        '            selX = x; selY = y;\n',
        '            isKing = piece.classList.contains("re");\n',
        '            validMoves = getValidMoves(x, y);\n',
        '            validMoves.forEach(id => document.getElementById("c_" + id).classList.add("valid-move"));\n',

        '            ghostPiece = piece.cloneNode(true);\n',
        '            ghostPiece.classList.add("floating-ghost");\n',
        '            document.body.appendChild(ghostPiece);\n',
        '            let offset = isKing ? 28 : 25;\n',
        '            ghostPiece.style.left = (event.pageX - offset) + "px";\n',
        '            ghostPiece.style.top = (event.pageY - offset - 15) + "px";\n',
        '            piece.style.opacity = "0"; /* Nasconde totalmente l\'originale */\n',
        '        }\n',
        '    } else {\n',
        '        let targetId = x + "_" + y;\n',
        '        let oldCell = document.getElementById("c_" + selX + "_" + selY);\n',
        '        let oldP = oldCell.querySelector(".piece");\n',
        '        \n',
        '        validMoves.forEach(id => document.getElementById("c_" + id).classList.remove("valid-move"));\n',
        '        \n',
        '        if (selX === x && selY === y) { \n',
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null; oldP.style.opacity = "1";\n',
        '            selX = null; selY = null; return; \n',
        '        }\n',
        '        \n',
        '        if (validMoves.includes(targetId)) {\n',
        '            let fx = selX; let fy = selY; selX = null; selY = null;\n',
        '            \n',
        '            /* FIX: Sposta e mostra subito il vero pezzo nella nuova cella! */\n',
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null;\n',
        '            oldP.style.opacity = "1";\n',
        '            oldP.classList.remove("floating");\n',
        '            oldP.classList.add("dropping");\n',
        '            cell.appendChild(oldP);\n',
        '            \n',
        '            fetch("/muovi?fx=" + fx + "&fy=" + fy + "&tx=" + x + "&ty=" + y)\n',
        '            .then(r => r.text()).then(res => {\n',
        '                if (res === "ok") {\n',
        '                    setTimeout(() => { window.location.reload(); }, 200);\n',
        '                } else { window.location.reload(); }\n',
        '            });\n',
        '        } else {\n',
        '            cell.style.backgroundColor = "#ff4c4c";\n',
        '            setTimeout(() => { cell.style.backgroundColor = ""; }, 300);\n',
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null; oldP.style.opacity = "1";\n',
        '            selX = null; selY = null;\n',
        '        }\n',
        '    }\n',
        '}\n\n',

        'if (statoGioco === "calcolo_ai") {\n',
        '    setTimeout(() => {\n',
        '        fetch("/trigger_ai").then(response => response.text()).then(res => { window.location.reload(); });\n',
        '    }, 300);\n',
        '}\n'
    ])).

renderizza_scacchiera(Pezzi) --> { kb:dimensione(N) }, html(table( \righe_scacchiera(1, N, Pezzi) )).

righe_scacchiera(Y, MaxY, _) --> { Y > MaxY }, !.
righe_scacchiera(Y, MaxY, Pezzi) --> html(tr(\celle_scacchiera(1, Y, MaxY, Pezzi))), { NextY is Y + 1 }, righe_scacchiera(NextY, MaxY, Pezzi).

celle_scacchiera(X, _, MaxX, _) --> { X > MaxX }, !.
celle_scacchiera(X, Y, MaxX, Pezzi) -->
    { ( kb:trono(X, Y) -> ClasseCella = 'board-cell throne'
      ; kb:dimensione(N), ( (X=1, Y=1) ; (X=1, Y=N) ; (X=N, Y=1) ; (X=N, Y=N) ) -> ClasseCella = 'board-cell corner'
      ; 0 =:= (X+Y) mod 2 -> ClasseCella = 'board-cell light'
      ; ClasseCella = 'board-cell dark'
      ),
      format(string(IdCella), "c_~w_~w", [X, Y]),
      format(string(AzioneClick), "clicca(~w, ~w, event)", [X, Y]),
      ( member(pezzo(Tipo, Fazione, X, Y), Pezzi) -> DatiPezzo = pezzo(Tipo, Fazione) ; DatiPezzo = vuoto )
    },
    html(td([id(IdCella), class(ClasseCella), onclick(AzioneClick)], \renderizza_pedina(DatiPezzo))),
    { NextX is X + 1 }, celle_scacchiera(NextX, Y, MaxX, Pezzi).

renderizza_pedina(vuoto) --> html('').
renderizza_pedina(pezzo(re, difensore)) --> html(div([class('piece re')], 'ᛟ')).
renderizza_pedina(pezzo(soldato, difensore)) --> html(div([class('piece difensore')], 'ᛏ')).
renderizza_pedina(pezzo(soldato, attaccante)) --> html(div([class('piece attaccante')], 'ᚦ')).

gestisci_mossa(Request) :-
    http_parameters(Request, [fx(FX, [integer]), fy(FY, [integer]), tx(TX, [integer]), ty(TY, [integer])]),
    stato_corrente(Pezzi), stato_gioco(turno_umano), 
    member(pezzo(_, FazioneMossa, FX, FY), Pezzi), ruolo_umano(RuoloAttuale),
    ( RuoloAttuale = sconosciuto ; RuoloAttuale = FazioneMossa ), 
    ( engine:mossa_legale(FX, FY, TX, TY, Pezzi) ->
        imposta_ruoli_se_necessario(FazioneMossa), 
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
            retractall(stato_gioco(_)), assertz(stato_gioco(V))
        ; retractall(stato_gioco(_)), assertz(stato_gioco(calcolo_ai)) ),
        format('Content-type: text/plain~n~nok')
    ; format('Content-type: text/plain~n~nko') ).

imposta_ruoli_se_necessario(FazioneMossa) :-
    ruolo_umano(sconosciuto), !, retractall(ruolo_umano(_)), assertz(ruolo_umano(FazioneMossa)),
    ai:avversario(FazioneMossa, Avv), retractall(ruolo_ai(_)), assertz(ruolo_ai(Avv)).
imposta_ruoli_se_necessario(_).

esegui_mossa_ai(_Request) :-
    stato_corrente(Pezzi), stato_gioco(calcolo_ai), ruolo_ai(FazioneAI),
    ( ai:calcola_mossa_ai(Pezzi, FazioneAI, 1, mossa(FX, FY, TX, TY)) ->
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
            retractall(stato_gioco(_)), assertz(stato_gioco(V))
        ; retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)) ),
        format('Content-type: text/plain~n~nok')
    ; retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)), format('Content-type: text/plain~n~nko_nessuna_mossa') ).
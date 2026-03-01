% =========================================================
% MODULO: server.pl (DASHBOARD WEB - TEXTURE 6K)
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

% --- ROTTE DEL SERVER ---
:- http_handler(root(.), pagina_principale, []).
:- http_handler(root(muovi), gestisci_mossa, []).
:- http_handler(root(trigger_ai), esegui_mossa_ai, []).
:- http_handler(root(reset), gestisci_reset, []).
:- http_handler(root('tavolo.jpg'), servi_immagine_tavolo, []). % <--- NUOVA ROTTA PER LA TEXTURE 6K!


servi_immagine_tavolo(Request) :-
    module_property(server, file(PathServer)),
    file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'tavolo.jpg', PathImmagine),
    % Abbiamo aggiunto unsafe(true) per dire a Prolog che questo file è sicuro da inviare!
    http_reply_file(PathImmagine, [unsafe(true)], Request).
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
    stato_corrente(Pezzi), stato_gioco(StatoGioco), ruolo_umano(RuoloUmano),
    reply_html_page(
        title('Hnefatafl - Diorama Vichingo Storico'),
        [
            style('
                /* Sfondo con la TUA Texture 6K */
                body { 
                    background-color: #1a1511; 
                    background-image: url("/tavolo.jpg?v=2");                    background-size: cover;
                    background-position: center;
                    background-attachment: fixed;
                    color: #e0d0b0; 
                    font-family: "Segoe UI", serif; 
                    text-align: center; 
                    user-select: none; 
                    margin: 0; padding-top: 10px; 
                    overflow-x: hidden; 
                }

                .btn-reset { background-color: rgba(26, 21, 17, 0.7); color: #c4a47c; border: 1px solid #c4a47c; padding: 8px 20px; cursor: pointer; margin-top: 5px; font-family: "Georgia", serif; font-weight: bold; text-transform: uppercase; letter-spacing: 2px; transition: all 0.2s; backdrop-filter: blur(4px); }
                .btn-reset:hover { background-color: #c4a47c; color: #1a1511; }
                
                table { border-collapse: collapse; border: 12px solid #2e1d10; border-radius: 4px; box-shadow: 0px 30px 70px rgba(0,0,0,0.95); margin: auto; background-color: #a47e57; background-image: url("https://www.transparenttextures.com/patterns/wood-pattern.png"); }
                .board-cell { width: 70px; height: 70px; text-align: center; vertical-align: middle; padding: 0; position: relative; border: 1px solid rgba(46, 29, 16, 0.8); }
                .board-cell.light { background-color: rgba(255,255,255,0.06); }
                .board-cell.dark { background-color: rgba(0,0,0,0.12); }
                .board-cell.throne { background-color: rgba(0,0,0,0.25); }
                .board-cell.corner { background-color: rgba(0,0,0,0.25); }
                .board-cell.corner::after { content: "ᛝ"; color: rgba(46, 29, 16, 0.5); font-size: 45px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none; }
                .board-cell.throne::after { content: "ᛝ"; color: rgba(0, 0, 0, 0.4); font-size: 45px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none; }
                
                .valid-move { box-shadow: inset 0 0 0 3px rgba(255, 215, 0, 0.5) !important; cursor: pointer; }
                
                .piece { width: 44px; height: 44px; border-radius: 50%; margin: 0 auto; display: flex; align-items: center; justify-content: center; font-size: 24px; font-weight: normal; position: relative; z-index: 10; cursor: pointer; pointer-events: none; border: 2px solid rgba(0,0,0,0.7); transition: all 0.15s ease-out; background-image: url("https://www.transparenttextures.com/patterns/retina-wood.png"); }
                .board-cell > .piece { pointer-events: auto; }
                
                .piece.attaccante { background-color: #3b2214; color: #1a0f08; text-shadow: 1px 1px 0px rgba(255,255,255,0.1); box-shadow: inset 0 0 8px rgba(0,0,0,0.9), 0 5px 0 #140b06, 0 8px 6px rgba(0,0,0,0.8); transform: translateY(-4px); }
                .piece.difensore { background-color: #d4c5b6; color: #4a3625; text-shadow: 1px 1px 0px rgba(255,255,255,0.6); box-shadow: inset 0 0 8px rgba(130,100,80,0.6), 0 5px 0 #7a6554, 0 8px 6px rgba(0,0,0,0.8); transform: translateY(-4px); }
                .piece.re { width: 50px; height: 50px; font-size: 28px; background-color: #cfa144; color: #3b280b; text-shadow: 1px 1px 0px rgba(255,255,255,0.4); box-shadow: inset 0 0 10px rgba(120,70,10,0.7), 0 7px 0 #78561b, 0 10px 8px rgba(0,0,0,0.9); transform: translateY(-6px); }
                
                .floating-ghost { position: absolute !important; z-index: 9999 !important; pointer-events: none !important; transition: left 0.1s linear, top 0.1s linear, transform 0.15s; transform: scale(1.1) translateY(-15px) !important; }
                .floating-ghost.attaccante { box-shadow: inset 0 0 8px rgba(0,0,0,0.9), 0 5px 0 #140b06, 0 25px 15px rgba(0,0,0,0.6) !important; }
                .floating-ghost.difensore { box-shadow: inset 0 0 8px rgba(130,100,80,0.6), 0 5px 0 #7a6554, 0 25px 15px rgba(0,0,0,0.6) !important; }
                .floating-ghost.re { box-shadow: inset 0 0 10px rgba(120,70,10,0.7), 0 7px 0 #78561b, 0 30px 20px rgba(0,0,0,0.6) !important; }
                
                .dropping { transform: translateY(0) scale(1) !important; box-shadow: 0 1px 0 rgba(0,0,0,0.8), 0 2px 3px rgba(0,0,0,0.8) !important; transition: all 0.1s ease-in !important; z-index: 10; }
                
                .banner-ai { color: #d4a348; padding: 10px; font-size: 16px; font-family: "Georgia", serif; font-style: italic; letter-spacing: 1px; background-color: rgba(26, 21, 17, 0.7); border-radius: 4px; width: fit-content; margin: 0 auto 15px auto; backdrop-filter: blur(4px); }
                .banner-win { background-color: rgba(74, 99, 17, 0.9); color: white; padding: 15px 40px; border-radius: 4px; width: fit-content; margin: 0 auto 15px auto; font-size: 20px; font-weight: bold; box-shadow: 0 10px 20px rgba(0,0,0,0.8); backdrop-filter: blur(4px); }
                .banner-loss { background-color: rgba(107, 0, 0, 0.9); color: white; padding: 15px 40px; border-radius: 4px; width: fit-content; margin: 0 auto 15px auto; font-size: 20px; font-weight: bold; box-shadow: 0 10px 20px rgba(0,0,0,0.8); backdrop-filter: blur(4px); }
            '),
            h1([style('margin-top: 15px; letter-spacing: 4px; margin-bottom: 5px; font-family: "Georgia", serif; color: #d1bfae; font-weight: normal; text-shadow: 2px 2px 5px #000;')], 'HNEFATAFL'),
            button([class('btn-reset'), onclick('fetch("/reset").then(()=>window.location.href = "/?t=" + Date.now())')], 'Nuova Battaglia'),
            div([style('height: 20px;')], ''),
            \banner_stato(StatoGioco),
            div([style('display: flex; justify-content: center; padding-bottom: 40px;')], \renderizza_scacchiera(Pezzi)),
            \script_javascript(StatoGioco, RuoloUmano)
        ]
    ).

banner_stato(calcolo_ai) --> html(div([class('banner-ai')], '... Il Nemico sta riflettendo ...')).
banner_stato(vittoria_attaccante) --> html(div([class('banner-loss')], 'VITTORIA! I Rossi hanno schiacciato il Re!')).
banner_stato(vittoria_difensore) --> html(div([class('banner-win')], 'VITTORIA! Il Re Bianco e fuggito!')).
banner_stato(_) --> html(div([style('height: 48px; margin-bottom: 15px;')], '')).

script_javascript(StatoGioco, RuoloUmano) -->
    { format(string(StatoStr), "~w", [StatoGioco]),
      format(string(RuoloStr), "~w", [RuoloUmano]) },
    html(script(type('text/javascript'), [
        'let statoGioco = "', StatoStr, '";\n',
        'let ruoloUmano = "', RuoloStr, '";\n',
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
        '            let isRestricted = cell.classList.contains("corner") || cell.classList.contains("throne");\n',
        '            if (!isKing && isRestricted) {\n',
        '                /* Puo passare SOPRA il trono vuoto, ma non fermarsi! */\n',
        '            } else {\n',
        '                valid.push(cx + "_" + cy);\n',
        '            }\n',
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
        '            let offset = isKing ? 25 : 22;\n',
        '            ghostPiece.style.left = (rect.left + rect.width/2 - offset) + "px";\n',
        '            ghostPiece.style.top = (rect.top + rect.height/2 - offset - 15) + "px";\n',
        '        } else {\n',
        '            let offset = isKing ? 25 : 22;\n',
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
        '            let isAtt = piece.classList.contains("attaccante");\n',
        '            let isDif = piece.classList.contains("difensore") || piece.classList.contains("re");\n',
        '            let fazionePezzo = isAtt ? "attaccante" : (isDif ? "difensore" : "sconosciuto");\n',
        '            if (ruoloUmano !== "sconosciuto" && fazionePezzo !== ruoloUmano) {\n',
        '                cell.style.backgroundColor = "rgba(255, 76, 76, 0.4)";\n',
        '                setTimeout(() => { cell.style.backgroundColor = ""; }, 300);\n',
        '                return;\n',
        '            }\n',
        '            selX = x; selY = y;\n',
        '            isKing = piece.classList.contains("re");\n',
        '            validMoves = getValidMoves(x, y);\n',
        '            validMoves.forEach(id => document.getElementById("c_" + id).classList.add("valid-move"));\n',

        '            ghostPiece = piece.cloneNode(true);\n',
        '            ghostPiece.classList.add("floating-ghost");\n',
        '            document.body.appendChild(ghostPiece);\n',
        '            let offset = isKing ? 25 : 22;\n',
        '            ghostPiece.style.left = (event.pageX - offset) + "px";\n',
        '            ghostPiece.style.top = (event.pageY - offset - 15) + "px";\n',
        '            piece.style.opacity = "0";\n',
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
        '                    window.location.href = "/?t=" + Date.now();\n',
        '                } else {\n',
        '                    oldCell.appendChild(oldP);\n',
        '                    oldP.classList.remove("dropping");\n',
        '                    cell.style.backgroundColor = "rgba(255, 76, 76, 0.4)";\n',
        '                    setTimeout(() => { cell.style.backgroundColor = ""; }, 300);\n',
        '                }\n',
        '            }).catch(() => { window.location.href = "/?t=" + Date.now(); });\n',
        '        } else {\n',
        '            cell.style.backgroundColor = "rgba(255, 76, 76, 0.4)";\n',
        '            setTimeout(() => { cell.style.backgroundColor = ""; }, 300);\n',
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null; oldP.style.opacity = "1";\n',
        '            selX = null; selY = null;\n',
        '        }\n',
        '    }\n',
        '}\n\n',

        'if (statoGioco === "calcolo_ai") {\n',
        '    setTimeout(() => {\n',
        '        fetch("/trigger_ai").then(response => response.text()).then(res => { window.location.href = "/?t=" + Date.now(); });\n',
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
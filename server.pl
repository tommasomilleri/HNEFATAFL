% =========================================================
% MODULO: server.pl (DASHBOARD WEB - TEXTURE FOTOREALISTICHE)
% =========================================================

:- module(server, [avvia_server/0, ferma_server/0, resetta_partita/0]).
:- encoding(utf8).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(library(www_browser)). 
:- use_module(library(random)). % AGGIUNTA LIBRERIA PER LA SELEZIONE CASUALE
:- use_module(kb).
:- use_module(engine).
:- use_module(ai).

% MEMORIA DINAMICA
:- dynamic stato_corrente/1, ruolo_umano/1, ruolo_ai/1, stato_gioco/1, turno_attuale/1.

% --- ROTTE DEL SERVER ---
:- http_handler(root(.), pagina_principale, []).
:- http_handler(root(muovi), gestisci_mossa, []).
:- http_handler(root(trigger_ai), esegui_mossa_ai, []).
:- http_handler(root(reset), gestisci_reset, []).

% ROTTE IMMAGINI
:- http_handler(root('tavolo.jpg'), servi_immagine_tavolo, []).
:- http_handler(root('wooden-warm-texture.jpg'), servi_texture_calda, []).
:- http_handler(root('wooden-textured-background.jpg'), servi_texture_scura, []).
:- http_handler(root('stone-shells-fossil-texture.jpg'), servi_texture_bianca, []).
:- http_handler(root('black-creased-textured-wall-background.jpg'), servi_texture_nera, []).
:- http_handler(root('yellow-wall-texture-with-scratches.jpg'), servi_texture_re, []).

% --- GESTIONE INVIO FILE IMMAGINE ---
servi_immagine_tavolo(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'tavolo.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

servi_texture_calda(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'wooden-warm-texture.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

servi_texture_scura(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'wooden-textured-background.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

servi_texture_bianca(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'stone-shells-fossil-texture.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

servi_texture_nera(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'black-creased-textured-wall-background.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

servi_texture_re(Request) :-
    module_property(server, file(PathServer)), file_directory_name(PathServer, Dir),
    directory_file_path(Dir, 'yellow-wall-texture-with-scratches.jpg', PathImmagine),
    http_reply_file(PathImmagine, [unsafe(true)], Request).

% --- COMANDI SERVER ---
avvia_server :-
    resetta_partita,
    http_server(http_dispatch, [port(8080)]),
    writeln('==========================================='),
    writeln('🚀 MOTORE HNEFATAFL 3D AVVIATO CON SUCCESSO!'),
    writeln('👉 Il browser si sta aprendo automaticamente...'),
    writeln('==========================================='),
    catch(www_open_url('http://localhost:8080'), _, true).

ferma_server :- http_stop_server(8080, _), writeln('🛑 Server fermato.').

resetta_partita :-
    kb:stato_iniziale(Pezzi),
    retractall(stato_corrente(_)), assertz(stato_corrente(Pezzi)),
    
    % --- ASSEGNAZIONE CASUALE FAZIONI ---
    random_member(MioRuolo, [attaccante, difensore]),
    ai:avversario(MioRuolo, RuoloIA),
    
    retractall(ruolo_umano(_)),    assertz(ruolo_umano(MioRuolo)),
    retractall(ruolo_ai(_)),       assertz(ruolo_ai(RuoloIA)),
    
    % REGOLE HNEFATAFL: L'Attaccante muove sempre per primo
    retractall(turno_attuale(_)),  assertz(turno_attuale(attaccante)),
    
    % Se la sorte ti ha dato il difensore, il gioco parte col turno dell'IA
    ( MioRuolo = difensore ->
        retractall(stato_gioco(_)), assertz(stato_gioco(calcolo_ai))
    ; 
        retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano))
    ).

gestisci_reset(_Request) :- resetta_partita, format('Content-type: text/plain~n~nok').

% --- INTERFACCIA WEB ---
pagina_principale(_Request) :-
    stato_corrente(Pezzi), stato_gioco(StatoGioco), ruolo_umano(RuoloUmano), turno_attuale(Turno),
    reply_html_page(
        title('Hnefatafl - Diorama Vichingo Storico'),
        [
            style('
                /* SFONDO DEL TAVOLO */
                body { 
                    background-color: #1a1511; 
                    background-image: url("/tavolo.jpg?v=5"); 
                    background-size: cover; background-position: center; background-attachment: fixed;
                    color: #e0d0b0; font-family: "Segoe UI", serif; text-align: center; user-select: none; margin: 0; padding-top: 10px; overflow-x: hidden; 
                }

                .btn-reset { background-color: rgba(26, 21, 17, 0.7); color: #c4a47c; border: 1px solid #c4a47c; padding: 8px 20px; cursor: pointer; margin-top: 5px; font-family: "Georgia", serif; font-weight: bold; text-transform: uppercase; letter-spacing: 2px; transition: all 0.2s; backdrop-filter: blur(4px); }
                .btn-reset:hover { background-color: #c4a47c; color: #1a1511; }
                
                /* ===================================================
                   LA PLANCIA DI GIOCO
                =================================================== */
                table { 
                    border-collapse: collapse; margin: auto; 
                    border: 24px solid #1a100a; 
                    border-radius: 8px; 
                    box-shadow: 0px 40px 80px rgba(0,0,0,0.9), inset 0 0 40px rgba(0,0,0,0.8); 
                    
                    /* TEXTURE LEGNO DELLA SCACCHIERA */
                    background-image: url("/wooden-textured-background.jpg?v=5");
                    background-size: cover;
                    background-position: center;
                }
                
                .board-cell { 
                    width: 72px; height: 72px; 
                    text-align: center; vertical-align: middle; padding: 0; position: relative; 
                    border: 2px solid rgba(15, 5, 0, 0.8); 
                }
                
                .board-cell.light { background-color: rgba(255,255,255,0.03); }
                .board-cell.dark { background-color: rgba(0,0,0,0.70); }
                
                .board-cell.throne { background-color: rgba(0, 0, 0, 0.5); box-shadow: inset 0 0 20px rgba(0,0,0,0.9); }
                .board-cell.corner { background-color: rgba(0, 0, 0, 0.6); box-shadow: inset 0 0 25px rgba(0,0,0,0.9); }
                
                .board-cell.corner::after { content: "ᛝ"; color: rgba(200, 150, 100, 0.3); font-size: 50px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none; }
                .board-cell.throne::after { content: "ᛝ"; color: rgba(200, 150, 100, 0.2); font-size: 50px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none; }
                
                .valid-move { box-shadow: inset 0 0 0 4px rgba(255, 200, 0, 0.6), inset 0 0 15px rgba(255,200,0,0.3) !important; cursor: pointer; }
                
                /* ===================================================
                   LE PEDINE
                =================================================== */
                .piece { 
                    width: 48px; height: 48px; border-radius: 50%; margin: 0 auto; 
                    display: flex; align-items: center; justify-content: center; 
                    font-size: 26px; font-weight: normal; position: relative; z-index: 10; 
                    cursor: pointer; pointer-events: none; transition: all 0.15s ease-out; 
                }
                .board-cell > .piece { pointer-events: auto; }
                
                /* PIETRA NERA RUVIDA (Attaccanti - Jötunn) */
                .piece.attaccante { 
                    background-color: #111111; 
                    background-image: url("/black-creased-textured-wall-background.jpg?v=5");
                    background-size: cover; background-position: center;
                    color: #ffffff; text-shadow: 0 0 4px rgba(255,255,255,0.8); border: 1px solid #000000;
                    box-shadow: inset -2px -3px 6px rgba(0,0,0,0.9), inset 2px 2px 5px rgba(255,255,255,0.2), 0 5px 0 #050505, 0 8px 6px rgba(0,0,0,0.9); 
                    transform: translateY(-3px); 
                }
                
                /* PIETRA FOSSILE / OSSO (Difensori - Einherjar) */
                .piece.difensore { 
                    background-color: #e3d5c8; 
                    background-image: url("/stone-shells-fossil-texture.jpg?v=5");
                    background-size: cover; background-position: center;
                    color: #111111; text-shadow: 1px 1px 0px rgba(255,255,255,0.8); border: 1px solid #8c7b6b;
                    box-shadow: inset -2px -3px 6px rgba(100,80,60,0.4), inset 2px 2px 4px rgba(255,255,255,0.6), 0 5px 0 #9c8a79, 0 8px 6px rgba(0,0,0,0.8); 
                    transform: translateY(-3px); 
                }
                
                /* IL RE (Odino) - Oro Antico Martellato */
                .piece.re { 
                    width: 56px; height: 56px; font-size: 32px; 
                    background-color: #d4af37; 
                    background-image: url("/yellow-wall-texture-with-scratches.jpg?v=5");
                    background-size: cover; background-position: center;
                    color: #ffffff; text-shadow: 2px 2px 4px rgba(0,0,0,0.8); border: 1px solid #5c4112;
                    box-shadow: inset -3px -4px 8px rgba(0,0,0,0.6), inset 3px 3px 6px rgba(255,255,255,0.7), 0 6px 0 #8a651f, 0 12px 10px rgba(0,0,0,0.9); 
                    transform: translateY(-4px); 
                }
                
                /* ===================================================
                   ANIMAZIONI E INTERFACCIA
                =================================================== */
                .floating-ghost { position: absolute !important; z-index: 9999 !important; pointer-events: none !important; transition: left 0.1s linear, top 0.1s linear, transform 0.15s; transform: scale(1.1) translateY(-15px) !important; }
                .floating-ghost.attaccante { box-shadow: inset -2px -3px 6px rgba(0,0,0,0.9), inset 2px 2px 5px rgba(255,255,255,0.2), 0 5px 0 #050505, 0 25px 15px rgba(0,0,0,0.6) !important; }
                .floating-ghost.difensore { box-shadow: inset -2px -3px 6px rgba(100,80,60,0.4), inset 2px 2px 4px rgba(255,255,255,0.6), 0 5px 0 #9c8a79, 0 25px 15px rgba(0,0,0,0.6) !important; }
                .floating-ghost.re { box-shadow: inset -3px -4px 8px rgba(0,0,0,0.6), inset 3px 3px 6px rgba(255,255,255,0.7), 0 6px 0 #8a651f, 0 30px 20px rgba(0,0,0,0.6) !important; }
                
                .dropping { transform: translateY(0) scale(1) !important; box-shadow: 0 1px 0 rgba(0,0,0,0.8), 0 2px 3px rgba(0,0,0,0.8) !important; transition: all 0.1s ease-in !important; z-index: 10; }
                
                .banner-ai, .banner-win, .banner-loss { padding: 10px 30px; border-radius: 4px; width: fit-content; margin: 0 auto 15px auto; font-family: "Georgia", serif; backdrop-filter: blur(4px); }
                .banner-ai { color: #d4a348; font-style: italic; background-color: rgba(26, 21, 17, 0.7); }
                .banner-win { background-color: rgba(74, 99, 17, 0.9); color: white; font-size: 20px; font-weight: bold; }
                .banner-loss { background-color: rgba(107, 0, 0, 0.9); color: white; font-size: 20px; font-weight: bold; }
            '),
            h1([style('margin-top: 15px; letter-spacing: 4px; margin-bottom: 5px; font-family: "Georgia", serif; color: #d1bfae; font-weight: normal; text-shadow: 2px 2px 5px #000;')], 'HNEFATAFL'),
            button([class('btn-reset'), onclick('fetch("/reset").then(()=>window.location.href = "/?t=" + Date.now())')], 'Nuova Battaglia'),
            
            % MOSTRA IL RUOLO ASSEGNATO CASUALMENTE
            div([style('color: #8c7b6b; font-size: 18px; font-family: "Georgia", serif; font-style: italic; margin-top: 10px; margin-bottom: 5px;')],
                ['Tu guidi: ', b([style('text-transform: capitalize; color: #c4a47c;')], RuoloUmano)]
            ),
            
            % CONTENITORE RIGIDO PER IL BANNER
            div([style('height: 60px; display: flex; flex-direction: column; justify-content: center; align-items: center; margin-bottom: 5px;')], 
                \banner_stato(StatoGioco)
            ),
            
            div([style('display: flex; justify-content: center; padding-bottom: 40px;')], \renderizza_scacchiera(Pezzi)),
            % PASSIAMO IL TURNO AL CLIENT JAVASCRIPT
            \script_javascript(StatoGioco, RuoloUmano, Turno)
        ]
    ).

% --- GESTIONE BANNER CON CUT DETERMINISTICI ---
banner_stato(calcolo_ai) --> !, html(div([class('banner-ai'), style('margin: 0;')], '... Il Nemico sta riflettendo ...')).
banner_stato(vittoria_attaccante) --> !, html(div([class('banner-loss'), style('margin: 0;')], 'VITTORIA! I Rossi hanno schiacciato il Re!')).
banner_stato(vittoria_difensore) --> !, html(div([class('banner-win'), style('margin: 0;')], 'VITTORIA! Il Re Bianco e fuggito!')).
banner_stato(_) --> html(''). % Fallback pulito senza div invisibili

script_javascript(StatoGioco, RuoloUmano, Turno) -->
    { format(string(StatoStr), "~w", [StatoGioco]),
      format(string(RuoloStr), "~w", [RuoloUmano]),
      format(string(TurnoStr), "~w", [Turno]) },
    html(script(type('text/javascript'), [
        'let statoGioco = "', StatoStr, '";\n',
        'let ruoloUmano = "', RuoloStr, '";\n',
        'let turnoAttuale = "', TurnoStr, '";\n',
        'let selX = null, selY = null;\n',
        'let ghostPiece = null;\n',
        'let validMoves = [];\n',
        'let isKing = false;\n\n',
        
        '/* UTILITY: Promessa per bloccare l esecuzione temporaneamente */\n',
        'const sleep = ms => new Promise(r => setTimeout(r, ms));\n\n',
        
        'function getValidMoves(sx, sy) {\n',
        '    let valid = [];\n',
        '    let dirs = [[0,-1], [0,1], [-1,0], [1,0]];\n',
        '    for(let d of dirs) {\n',
        '        let cx = sx + d[0]; let cy = sy + d[1];\n',
        '        while(cx >= 1 && cx <= 9 && cy >= 1 && cy <= 9) {\n',
        '            let cell = document.getElementById("c_" + cx + "_" + cy);\n',
        '            if (cell.querySelector(".piece")) break; \n',
        '            let isRestricted = cell.classList.contains("corner") || cell.classList.contains("throne");\n',
        '            if (!isKing && isRestricted) {}\n',
        '            else { valid.push(cx + "_" + cy); }\n',
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
        '            let offset = isKing ? 28 : 24;\n',
        '            ghostPiece.style.left = (rect.left + rect.width/2 - offset) + "px";\n',
        '            ghostPiece.style.top = (rect.top + rect.height/2 - offset - 15) + "px";\n',
        '        } else {\n',
        '            let offset = isKing ? 28 : 24;\n',
        '            ghostPiece.style.left = (e.pageX - offset) + "px";\n',
        '            ghostPiece.style.top = (e.pageY - offset - 15) + "px";\n',
        '        }\n',
        '    }\n',
        '});\n\n',

        'async function clicca(x, y, event) {\n',
        '    if (statoGioco !== "turno_umano") return;\n',
        '    let cell = document.getElementById("c_" + x + "_" + y);\n',
        '    let piece = cell.querySelector(".piece");\n',

        '    if (selX === null) {\n',
        '        if (piece) {\n',
        '            let isAtt = piece.classList.contains("attaccante");\n',
        '            let isDif = piece.classList.contains("difensore") || piece.classList.contains("re");\n',
        '            let fazionePezzo = isAtt ? "attaccante" : (isDif ? "difensore" : "sconosciuto");\n',
        '            \n',
        '            if (fazionePezzo !== turnoAttuale || (ruoloUmano !== "sconosciuto" && fazionePezzo !== ruoloUmano)) {\n',
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
        '            let offset = isKing ? 28 : 24;\n',
        '            ghostPiece.style.left = (event.pageX - offset) + "px";\n',
        '            ghostPiece.style.top = (event.pageY - offset - 15) + "px";\n',
        '            piece.style.opacity = "0";\n',
        '        }\n',
        '    } else {\n',
        '        let targetId = x + "_" + y;\n',
        '        let oldCell = document.getElementById("c_" + selX + "_" + selY);\n',
        '        let oldP = oldCell.querySelector(".piece");\n',
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
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null;\n',
        '            oldP.style.opacity = "1";\n',
        '            oldP.classList.remove("floating", "dropping");\n',
        '            cell.appendChild(oldP);\n',
        '            \n',
        '            /* ANIMAZIONE: Lasciamo depositare la pedina prima di inviare al server */\n',
        '            await sleep(200);\n',
        '            \n',
        '            try {\n',
        '                let res = await fetch(`/muovi?fx=${fx}&fy=${fy}&tx=${x}&ty=${y}`).then(r => r.text());\n',
        '                if (res === "ok") {\n',
        '                    window.location.href = "/?t=" + Date.now();\n',
        '                } else {\n',
        '                    oldCell.appendChild(oldP);\n',
        '                    oldP.classList.remove("dropping");\n',
        '                    cell.style.backgroundColor = "rgba(255, 76, 76, 0.4)";\n',
        '                    await sleep(300);\n',
        '                    cell.style.backgroundColor = "";\n',
        '                }\n',
        '            } catch(e) { window.location.href = "/?t=" + Date.now(); }\n',
        '        } else {\n',
        '            cell.style.backgroundColor = "rgba(255, 76, 76, 0.4)";\n',
        '            setTimeout(() => { cell.style.backgroundColor = ""; }, 300);\n',
        '            if(ghostPiece) ghostPiece.remove();\n',
        '            ghostPiece = null; oldP.style.opacity = "1";\n',
        '            selX = null; selY = null;\n',
        '        }\n',
        '    }\n',
        '}\n\n',

        /* --- INTELLIGENZA ARTIFICIALE CON TIMELINE ORDINATA --- */
        'if (statoGioco === "calcolo_ai") {\n',
        '    setTimeout(async () => {\n',
        '        try {\n',
        '            let res = await fetch("/trigger_ai").then(r => r.text());\n',
        '            if (res.includes(",")) {\n',
        '                let parts = res.trim().split(",");\n',
        '                let oldCell = document.getElementById("c_" + parts[0] + "_" + parts[1]);\n',
        '                let targetCell = document.getElementById("c_" + parts[2] + "_" + parts[3]);\n',
        '                \n',
        '                if (oldCell && targetCell) {\n',
        '                    let piece = oldCell.querySelector(".piece");\n',
        '                    if (piece) {\n',
        '                        let r1 = piece.getBoundingClientRect();\n',
        '                        let r2 = targetCell.getBoundingClientRect();\n',
        '                        let dx = r2.left - r1.left + (r2.width - r1.width)/2;\n',
        '                        let dy = r2.top - r1.top + (r2.height - r1.height)/2;\n',
        '                        \n',
        '                        /* 1. Volo della pedina */\n',
        '                        piece.style.zIndex = "9999";\n',
        '                        piece.style.transition = "transform 0.5s cubic-bezier(0.25, 1, 0.5, 1)";\n',
        '                        piece.style.transform = `translate(${dx}px, ${dy - 15}px) scale(1.15)`;\n',
        '                        \n',
        '                        await sleep(500);\n',
        '                        \n',
        '                        /* 2. Impatto (Si abbassa e fa capire la destinazione) */\n',
        '                        piece.style.transition = "none";\n',
        '                        piece.style.transform = "";\n',
        '                        targetCell.appendChild(piece);\n',
        '                        piece.style.zIndex = "";\n',
        '                        \n',
        '                        /* 3. Pausa di percezione prima del reload */\n',
        '                        await sleep(400);\n',
        '                    }\n',
        '                }\n',
        '            }\n',
        '            /* 4. Aggiornamento Globale */\n',
        '            window.location.href = "/?t=" + Date.now();\n',
        '        } catch(e) {\n',
        '            window.location.href = "/?t=" + Date.now();\n',
        '        }\n',
        '    }, 400);\n',
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
    turno_attuale(TurnoAttuale),
    member(pezzo(_, FazioneMossa, FX, FY), Pezzi),
    
    % VALIDAZIONE SERVER-SIDE DEL TURNO 
    FazioneMossa = TurnoAttuale,
    
    ruolo_umano(RuoloAttuale), 
    ( RuoloAttuale = sconosciuto ; RuoloAttuale = FazioneMossa ), 
    ( engine:mossa_legale(FX, FY, TX, TY, Pezzi) ->
        engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
        retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
        
        % PASSA IL TURNO ALL'AVVERSARIO DOPO UNA MOSSA LEGALE
        ai:avversario(FazioneMossa, ProssimoTurno),
        retractall(turno_attuale(_)), assertz(turno_attuale(ProssimoTurno)),
        
        ( engine:vittoria(NuoviPezzi, Vincitore) ->
            (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
            retractall(stato_gioco(_)), assertz(stato_gioco(V))
        ; retractall(stato_gioco(_)), assertz(stato_gioco(calcolo_ai)) ),
        format('Content-type: text/plain~n~nok')
    ; format('Content-type: text/plain~n~nko') ).

esegui_mossa_ai(_Request) :-
    catch(
        (
            stato_corrente(Pezzi), stato_gioco(calcolo_ai), ruolo_ai(FazioneAI), turno_attuale(FazioneAI),
            
            % PROFONDITÀ A 3: Veloce e spietata!
            ( ai:calcola_mossa_ai(Pezzi, FazioneAI, 3, mossa(FX, FY, TX, TY)) ->
                engine:applica_mossa(FX, FY, TX, TY, Pezzi, NuoviPezzi),
                retractall(stato_corrente(_)), assertz(stato_corrente(NuoviPezzi)),
                ai:avversario(FazioneAI, ProssimoTurno),
                retractall(turno_attuale(_)), assertz(turno_attuale(ProssimoTurno)),
                ( engine:vittoria(NuoviPezzi, Vincitore) ->
                    (Vincitore = attaccante -> V = vittoria_attaccante ; V = vittoria_difensore),
                    retractall(stato_gioco(_)), assertz(stato_gioco(V))
                ; retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)) ),
                
                % INVIO COORDINATE AL JAVASCRIPT PER L'ANIMAZIONE!
                format('Content-type: text/plain~n~n~w,~w,~w,~w', [FX, FY, TX, TY])
                
            ; retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)), format('Content-type: text/plain~n~nko_nessuna_mossa') )
        ),
        _Error,
        (
            % FAIL-SAFE DI EMERGENZA
            retractall(stato_gioco(_)), assertz(stato_gioco(turno_umano)),
            format('Content-type: text/plain~n~nko_server_error')
        )
    ).
% =========================================================
% MODULO: ui.pl (THEME LEATHER + RUNE BORDER + TRUECOLOR)
% =========================================================

:- module(ui, [mostra_scacchiera/5]).
:- encoding(utf8).
:- use_module(kb).
:- use_module(library(ansi_term)).

% --- TrueColor helpers (SGR 24-bit)
esc(Seq) :- format('\e[~w', [Seq]).
reset    :- esc('0m').

fg_rgb(R,G,B) :- format('\e[38;2;~d;~d;~dm', [R,G,B]).
bg_rgb(R,G,B) :- format('\e[48;2;~d;~d;~dm', [R,G,B]).

% --- Palette "cuoio/legno inciso"
leather_light(206, 170, 120).
leather_dark(188, 150, 105).
ink_brown(90, 60, 40).
gold_ink(210, 170, 70).
ivory(235, 230, 220).
charcoal(25, 25, 25).
moss(70, 120, 70).
deep_blue(60, 90, 140).

% --- Glifi: rune per pezzi e marcatori
glyph(king,      'ᛟ').
glyph(defender,  'ᛏ').
glyph(attacker,  'ᚦ').
glyph(throne,    'ᛝ').
glyph(corner,    'ᚠ').

cell_text(Type, Txt) :-
    ( Type = king      -> glyph(king, G)
    ; Type = defender  -> glyph(defender, G)
    ; Type = attacker  -> glyph(attacker, G)
    ; Type = throne    -> glyph(throne, G)
    ; Type = corner    -> glyph(corner, G)
    ; Type = empty     -> G = ' '
    ),
    format(string(Txt), " ~w ", [G]).

% --- Bordo decorativo runico
rune_strip('ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ').

repeat_to_len(Str, Len, Out) :-
    string_length(Str, L),
    ( L >= Len ->
        sub_string(Str, 0, Len, _, Out)
    ;   string_concat(Str, Str, DoubleStr),
        repeat_to_len(DoubleStr, Len, Out)
    ).

print_rune_border(N) :-
    rune_strip(Base),
    Len is N*4 + 1,
    repeat_to_len(Base, Len, Out),
    ink_brown(R,G,B), fg_rgb(R,G,B),
    format("   ~w~n", [Out]),
    reset.

% --- Griglia “incisa” (box-drawing)
hline(N) :-
    ink_brown(R,G,B), fg_rgb(R,G,B),
    write("   "), write("┌"),
    forall(between(1, N, X),
        ( write("───"),
          ( X =:= N -> write("┐") ; write("┬") )
        )),
    nl, reset.

mline(N) :-
    ink_brown(R,G,B), fg_rgb(R,G,B),
    write("   "), write("├"),
    forall(between(1, N, X),
        ( write("───"),
          ( X =:= N -> write("┤") ; write("┼") )
        )),
    nl, reset.

bline(N) :-
    ink_brown(R,G,B), fg_rgb(R,G,B),
    write("   "), write("└"),
    forall(between(1, N, X),
        ( write("───"),
          ( X =:= N -> write("┘") ; write("┴") )
        )),
    nl, reset.

vbar :- ink_brown(R,G,B), fg_rgb(R,G,B), write("│"), reset.

% --- Selettori: cursore e selezione
apply_overlay_bg(X,Y,CX,CY,SelX,SelY) :-
    ( X =:= SelX, Y =:= SelY -> moss(R,G,B), bg_rgb(R,G,B)
    ; X =:= CX, Y =:= CY     -> deep_blue(R,G,B), bg_rgb(R,G,B)
    ; true
    ).

% --- Base background cuoio
base_bg(X,Y) :-
    ( kb:trono(X,Y) -> leather_dark(R,G,B), bg_rgb(R,G,B)
    ; corner_square(X,Y) -> leather_dark(R,G,B), bg_rgb(R,G,B)
    ; 0 is (X+Y) mod 2 -> leather_light(R,G,B), bg_rgb(R,G,B)
    ; leather_dark(R,G,B), bg_rgb(R,G,B)
    ).

corner_square(X,Y) :-
    kb:dimensione(N),
    ( (X=:=1, Y=:=1) ; (X=:=1, Y=:=N) ; (X=:=N, Y=:=1) ; (X=:=N, Y=:=N) ).

% --- Colore del simbolo
piece_fg(Type) :-
    ( Type = king     -> gold_ink(R,G,B), fg_rgb(R,G,B)
    ; Type = defender -> ivory(R,G,B), fg_rgb(R,G,B)
    ; Type = attacker -> gold_ink(R,G,B), fg_rgb(R,G,B)
    ; Type = throne   -> gold_ink(R,G,B), fg_rgb(R,G,B)
    ; Type = corner   -> gold_ink(R,G,B), fg_rgb(R,G,B)
    ; ink_brown(R,G,B), fg_rgb(R,G,B)
    ).

% --- Determina cosa stampare in cella
cell_type_at(X,Y,Pezzi,Type) :-
    ( member(pezzo(re, _, X, Y), Pezzi)         -> Type = king
    ; member(pezzo(_, difensore, X, Y), Pezzi)  -> Type = defender
    ; member(pezzo(_, attaccante, X, Y), Pezzi) -> Type = attacker
    ; kb:trono(X, Y)                            -> Type = throne
    ; corner_square(X,Y)                        -> Type = corner
    ; Type = empty
    ).

stampa_cella(X,Y,Pezzi,CX,CY,SelX,SelY) :-
    base_bg(X,Y),
    apply_overlay_bg(X,Y,CX,CY,SelX,SelY),
    cell_type_at(X,Y,Pezzi,Type),
    piece_fg(Type),
    cell_text(Type, Txt),
    write(Txt),
    reset.

mostra_scacchiera(Pezzi, CX, CY, SelX, SelY) :-
    write('\e[2J\e[H'), % Pulisce lo schermo
    kb:dimensione(N),
    print_rune_border(N),
    hline(N),
    forall(between(1, N, Y),
        ( format("~` t~d~2+ ", [Y]),
          vbar,
          forall(between(1, N, X),
              ( stampa_cella(X,Y,Pezzi,CX,CY,SelX,SelY),
                vbar
              )),
          nl,
          ( Y =:= N -> bline(N) ; mline(N) )
        )),
    print_rune_border(N),
    nl,
    stampa_messaggi(SelX, SelY).

stampa_messaggi(0, 0) :-
    ansi_format([bold], 'W A S D muovi il cursore. SPAZIO seleziona/sposta. Q esce.~n', []).
stampa_messaggi(_, _) :-
    ansi_format([bold], 'Pezzo selezionato: muovi il cursore e premi SPAZIO per confermare.~n', []).
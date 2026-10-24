; =====================================================================
;  G A T O  (Tic-Tac-Toe) - Proyecto 2, EIF205 Arquitectura de Computadoras
;  Universidad Nacional (Costa Rica), 2026 - EMU8086
;  Codigo base: https://github.com/shairaziz/TicTacToe (modificado)
;  Instrucciones y detalles: ver README.md y el informe tecnico.
;
;  Tablero (BOARD): 9 bytes, posiciones 0..8 de izquierda a derecha y
;  de arriba hacia abajo. 0 = vacia, 1 = jugador (X), 2 = computadora (O).
; =====================================================================


; ---------------------------------------------------------------------
;  MACROS
; ---------------------------------------------------------------------

; IMPRIMIR: muestra un texto terminado en '$' (INT 21h/09h).
;   Parametro: msg = nombre de la variable con el texto.
;   No cambia ningun registro (guarda AX y DX en la pila).
IMPRIMIR MACRO msg
    PUSH AX
    PUSH DX
    LEA  DX, msg
    MOV  AH, 09h
    INT  21h
    POP  DX
    POP  AX
ENDM

; LIMPIAR_PANTALLA: borra la pantalla poniendo de nuevo el modo texto
;   80x25 (INT 10h, AX = 0003h). No cambia ningun registro.
LIMPIAR_PANTALLA MACRO
    PUSH AX
    MOV  AX, 0003h
    INT  10h
    POP  AX
ENDM


; ---------------------------------------------------------------------
;  CONSTANTES
; ---------------------------------------------------------------------

; Tiempo que la computadora "piensa" antes de jugar, en centesimas de
; segundo (100 = 1 segundo). Debe ser menor que 6000 (60 segundos).
RETRASO_CPU EQU 100


.MODEL SMALL
.STACK 100H


; =====================================================================
;  SEGMENTO DE DATOS
; =====================================================================
.DATA

    ; Tablero de 9 casillas (ver "REPRESENTACION DEL TABLERO" arriba)
    BOARD           DB  9 DUP(0)

    ; Turno actual: 1 = jugador, 2 = computadora
    CURRENT_TURN    DB  1

    ; Estado de la partida: 0 = en curso, 1 = gano el jugador,
    ; 2 = gano la computadora, 3 = empate
    GAME_STATE      DB  0

    ; Marcador: partidas ganadas por cada uno
    PLAYER_SCORE    DB  0
    COMP_SCORE      DB  0

    ; Las 8 lineas ganadoras: cada fila de 3 bytes son las posiciones
    ; del tablero que forman una linea
    WIN_TABLE       DB  0,1,2           ; fila de arriba
                    DB  3,4,5           ; fila del medio
                    DB  6,7,8           ; fila de abajo
                    DB  0,3,6           ; columna izquierda
                    DB  1,4,7           ; columna del centro
                    DB  2,5,8           ; columna derecha
                    DB  0,4,8           ; diagonal principal
                    DB  2,4,6           ; diagonal secundaria

    ; --- Mensajes de la partida (todos terminan en '$') ---
    MSG_INVALID     DB  'Invalid! Try again (1-9, empty cell): $'
    MSG_PLAYER_WIN  DB  'YOU WIN! Congratulations!$'
    MSG_COMP_WIN    DB  'COMPUTER WINS!$'
    MSG_DRAW        DB  'DRAW! Well played.$'
    MSG_NEWLINE     DB  0Dh, 0Ah, '$'      ; salto de linea (CR + LF)

    ; --- Piezas para dibujar el tablero ---
    MSG_BAR         DB  ' | $'                          ; separador de columnas
    MSG_DASH        DB  '---------',0Dh,0Ah,'$'         ; separador de filas
    MSG_TITULO      DB  '=====  G A T O  =====',0Dh,0Ah,'$'

    ; --- Mensajes de turno, menu de fin y marcador ---
    MSG_YOUR_TURN   DB  0Dh,0Ah,'>>  YOUR TURN! Enter 1-9',0Dh,0Ah,'$'
    MSG_COMP_TURN   DB  0Dh,0Ah,'>>  COMPUTER IS THINKING...',0Dh,0Ah,'$'
    MSG_REPLAY_ASK  DB  0Dh,0Ah,'  Play again?  Y = Yes   N = No',0Dh,0Ah, '  Your choice: $'
    MSG_INVALID_KEY DB  0Dh,0Ah, '  Invalid! Press Y or N only.',0Dh,0Ah,'$'
    MSG_REPLAYING   DB  0Dh,0Ah,'  Starting new game...',0Dh,0Ah,'$'
    MSG_GOODBYE     DB  0Dh,0Ah, '  Thanks for playing! Goodbye!',0Dh,0Ah,'$'
    MSG_GAME_OVER   DB  0Dh,0Ah
                    DB  '==================================',0Dh,0Ah
                    DB  '        G A M E   O V E R        ',0Dh,0Ah
                    DB  '==================================',0Dh,0Ah,'$'
    MSG_SCORE_HDR   DB  0Dh,0Ah,' - SCOREBOARD - ',0Dh,0Ah,'$'
    MSG_PSCORE      DB  '  You     : $'
    MSG_CSCORE      DB  '  Computer: $'

    ; --- Mensajes para elegir quien empieza ---
    MSG_WHO_FIRST   DB  0Dh,0Ah,'  Who goes first?  P = Player   C = Computer',0Dh,0Ah,'  Your choice: $'
    MSG_INVALID_KEY2 DB  0Dh,0Ah, '  Invalid! Press P or C only.',0Dh,0Ah,'$'


; =====================================================================
;  SEGMENTO DE CODIGO
; =====================================================================
.CODE

; ---------------------------------------------------------------------
;  MAIN: programa principal y ciclo del juego
;    1. Reinicia el tablero y pregunta quien empieza.
;    2. Ciclo: si la partida termino, muestra el resultado; si no,
;       juega el jugador o la computadora segun CURRENT_TURN.
;    3. Al terminar, pregunta si se juega otra vez (vuelve al paso 1)
;       o se sale al sistema.
; ---------------------------------------------------------------------
MAIN PROC
    MOV  AX, @DATA              ; DS apunta al segmento de datos
    MOV  DS, AX

OUTER_REPLAY_GAME_LOOP:         ; aqui empieza cada partida nueva
    CALL RESET_GAME
    LIMPIAR_PANTALLA            ; pantalla limpia al iniciar cada partida
    IMPRIMIR MSG_TITULO
    CALL ASK_WHO_FIRST
    CALL DRAW_BOARD             ; muestra el tablero vacio desde el inicio

GAME_LOOP:
    ; Si la partida ya termino (GAME_STATE distinto de 0), mostrar resultado
    MOV  AL, GAME_STATE
    CMP  AL, 0
    JNE  SHOW_RESULT

    ; Si no, ver a quien le toca
    MOV  AL, CURRENT_TURN
    CMP  AL, 1
    JE   DO_PLAYER_TURN
    JMP  DO_COMPUTER_TURN

; --- Turno del jugador ---
DO_PLAYER_TURN:
    MOV  AL, 0                  ; 0 = mostrar "YOUR TURN"
    CALL SHOW_TURN_INDICATOR

    ; Leer una tecla (INT 21h/01h la deja en AL y la muestra)
    MOV  AH, 01h
    INT  21h

    ; Convertir el caracter '1'..'9' en la posicion 0..8 del tablero
    MOV  BL, AL
    SUB  BL, '1'
    MOV  BH, 0

    ; Fuera de rango (menor que '1' o mayor que '9'): jugada invalida
    CMP  BL, 0
    JL   INVALID_MOVE
    CMP  BL, 8
    JG   INVALID_MOVE

    ; Casilla ocupada: jugada invalida
    MOV  BH, 0
    MOV  AL, BOARD[BX]
    CMP  AL, 0
    JNE  INVALID_MOVE

    ; Jugada valida: marcar la casilla con 1 (X)
    MOV  BH, 0
    MOV  BOARD[BX], 1
    CALL PRINT_NEWLINE
    CALL DRAW_BOARD
    CALL CHECK_WIN_DRAW         ; actualiza GAME_STATE

    MOV  CURRENT_TURN, 2        ; ahora le toca a la computadora
    JMP  GAME_LOOP

INVALID_MOVE:
    CALL DRAW_BOARD             ; redibuja el tablero para no acumular texto
    CALL PRINT_NEWLINE
    IMPRIMIR MSG_INVALID
    CALL PRINT_NEWLINE
    JMP  GAME_LOOP              ; vuelve a pedir la jugada

; --- Turno de la computadora ---
DO_COMPUTER_TURN:
    MOV  AL, 1                  ; 1 = mostrar "COMPUTER IS THINKING"
    CALL SHOW_TURN_INDICATOR

    MOV  AX, RETRASO_CPU        ; pausa mientras se muestra "THINKING..."
    CALL ESPERAR

    CALL COMPUTER_MOVE          ; elige y marca una casilla con 2 (O)
    CALL DRAW_BOARD
    CALL CHECK_WIN_DRAW         ; actualiza GAME_STATE

    MOV  CURRENT_TURN, 1        ; ahora le toca al jugador
    JMP  GAME_LOOP

; --- Fin de la partida: mostrar quien gano y sumar al marcador ---
SHOW_RESULT:
    CALL PRINT_NEWLINE
    MOV  AL, GAME_STATE

    CMP  AL, 1
    JE   PLAYER_WINS
    CMP  AL, 2
    JE   COMP_WINS

    IMPRIMIR MSG_DRAW           ; GAME_STATE = 3: empate
    CALL PRINT_NEWLINE
    JMP  DO_REPLAY_MENU

PLAYER_WINS:
    INC  PLAYER_SCORE
    IMPRIMIR MSG_PLAYER_WIN
    CALL PRINT_NEWLINE
    JMP  DO_REPLAY_MENU

COMP_WINS:
    INC  COMP_SCORE
    IMPRIMIR MSG_COMP_WIN
    CALL PRINT_NEWLINE

DO_REPLAY_MENU:
    CALL SHOW_REPLAY_MENU       ; devuelve AX = 1 (jugar otra vez) o 0 (salir)

    CMP  AX, 1
    JE   OUTER_REPLAY_GAME_LOOP

    MOV  AX, 4C00H              ; INT 21h/4Ch: terminar el programa
    INT  21H

MAIN ENDP


; ---------------------------------------------------------------------
;  CHECK_WIN_DRAW: revisa si alguien gano o si hay empate
;    Recorre las 8 lineas de WIN_TABLE. Si las 3 casillas de una linea
;    tienen el mismo valor y no estan vacias, ese valor (1 o 2) es el
;    ganador. Si nadie gano y no quedan casillas vacias, es empate.
;    Salida: GAME_STATE = 0 (sigue), 1 (jugador), 2 (computadora),
;            3 (empate). No cambia ningun registro.
; ---------------------------------------------------------------------
CHECK_WIN_DRAW PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  SI, 0                  ; SI = inicio de la linea en WIN_TABLE
    MOV  CX, 8                  ; 8 lineas por revisar

WIN_LOOP:
    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI]
    MOV  AL, BOARD[BX]          ; AL = valor de la 1a casilla de la linea

    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI+1]
    MOV  AH, BOARD[BX]          ; AH = valor de la 2a casilla

    CMP  AL, AH                 ; 1a igual a 2a?
    JNE  NEXT_LINE

    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI+2]
    MOV  DL, BOARD[BX]          ; DL = valor de la 3a casilla

    CMP  AL, DL                 ; 1a igual a 3a?
    JNE  NEXT_LINE

    CMP  AL, 0                  ; las 3 iguales pero vacias: no cuenta
    JE   NEXT_LINE

    ; Hay ganador: AL = 1 (jugador) o 2 (computadora)
    MOV  GAME_STATE, AL
    JMP  WIN_DONE

NEXT_LINE:
    ADD  SI, 3                  ; siguiente linea (3 bytes mas adelante)
    LOOP WIN_LOOP

    ; Nadie gano: revisar si el tablero esta lleno (empate)
    MOV  CX, 9
    MOV  SI, 0

DRAW_LOOP:
    MOV  BH, 0
    MOV  BX, SI
    MOV  AL, BOARD[BX]
    CMP  AL, 0
    JE   WIN_DONE               ; hay una casilla vacia: no es empate
    INC  SI
    LOOP DRAW_LOOP

    MOV  GAME_STATE, 3          ; las 9 casillas llenas: empate

WIN_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CHECK_WIN_DRAW ENDP


; ---------------------------------------------------------------------
;  DRAW_BOARD: borra la pantalla y dibuja el titulo y el tablero
;    Las casillas vacias muestran su numero (1-9), las del jugador una
;    X y las de la computadora una O. No cambia ningun registro.
; ---------------------------------------------------------------------
DRAW_BOARD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    LIMPIAR_PANTALLA            ; borra la pantalla: el tablero siempre queda arriba
    IMPRIMIR MSG_TITULO
    CALL PRINT_NEWLINE

    MOV  CX, 9                  ; 9 casillas
    MOV  BX, 0                  ; BX = posicion actual (0..8)

DRAW_CELL:
    MOV  AL, BOARD[BX]          ; valor de la casilla

    CMP  AL, 0
    JE   PRINT_NUMBER
    CMP  AL, 1
    JE   PRINT_X

PRINT_O:                        ; valor 2: computadora
    MOV  DL, 'O'
    JMP  PRINT_CHAR

PRINT_X:                        ; valor 1: jugador
    MOV  DL, 'X'
    JMP  PRINT_CHAR

PRINT_NUMBER:                   ; valor 0: vacia, muestra posicion + 1
    MOV  DL, BL
    ADD  DL, '1'

PRINT_CHAR:
    MOV  AH, 02h                ; INT 21h/02h: mostrar el caracter de DL
    INT  21h

    ; Despues de las posiciones 2 y 5 termina una fila: dibujar la raya
    CMP  BL, 2
    JE   ROW_END
    CMP  BL, 5
    JE   ROW_END
    CMP  BL, 8                  ; la posicion 8 es la ultima casilla
    JE   BOARD_DONE_ROW

    IMPRIMIR MSG_BAR            ; separador entre columnas
    JMP  NEXT_CELL

ROW_END:
    CALL PRINT_NEWLINE
    IMPRIMIR MSG_DASH           ; raya entre filas
    JMP  NEXT_CELL

BOARD_DONE_ROW:
    CALL PRINT_NEWLINE

NEXT_CELL:
    INC  BX
    LOOP DRAW_CELL

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DRAW_BOARD ENDP


; ---------------------------------------------------------------------
;  COMPUTER_MOVE: la computadora elige su jugada y la marca con 2 (O)
;    1. Si puede ganar completando una linea, la completa.
;    2. Si no, si el jugador esta por ganar, lo bloquea.
;    3. Si no, toma la primera casilla vacia.
;    No cambia ningun registro.
; ---------------------------------------------------------------------
COMPUTER_MOVE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    ; 1) Buscar una linea donde la computadora pueda ganar
    MOV  SI, 0
    MOV  CX, 8

WIN_SCAN_LOOP:
    CALL TRY_WIN_LINE           ; AL = 1 si ya jugo
    CMP  AL, 1
    JE   COMPUTER_DONE

    ADD  SI, 3
    LOOP WIN_SCAN_LOOP

    ; 2) Buscar una linea donde haya que bloquear al jugador
    MOV  SI, 0
    MOV  CX, 8

BLOCK_LOOP:
    CALL TRY_BLOCK_LINE         ; AL = 1 si ya jugo
    CMP  AL, 1
    JE   COMPUTER_DONE

    ADD  SI, 3
    LOOP BLOCK_LOOP

    ; 3) Tomar la primera casilla vacia
    MOV  CX, 9
    MOV  BX, 0

RANDOM_SCAN:
    MOV  BH, 0
    MOV  AL, BOARD[BX]
    CMP  AL, 0
    JE   RANDOM_PLACE
    INC  BX
    LOOP RANDOM_SCAN
    JMP  COMPUTER_DONE          ; no hay casillas vacias

RANDOM_PLACE:
    MOV  BOARD[BX], 2

COMPUTER_DONE:
    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
COMPUTER_MOVE ENDP


; ---------------------------------------------------------------------
;  TRY_WIN_LINE: intenta ganar en una linea
;    Entrada: SI = inicio de la linea en WIN_TABLE.
;    Si la computadora (2) tiene 2 casillas de la linea y la tercera
;    esta vacia, marca la tercera con 2.
;    Salida: AL = 1 si jugo, AL = 0 si no. No cambia otros registros.
; ---------------------------------------------------------------------
TRY_WIN_LINE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AL, 0                  ; por ahora: no jugo

    MOV  BL, WIN_TABLE[SI]
    MOV  BH, 0
    MOV  CL, BOARD[BX]          ; CL = 1a casilla

    MOV  BL, WIN_TABLE[SI+1]
    MOV  BH, 0
    MOV  CH, BOARD[BX]          ; CH = 2a casilla

    MOV  BL, WIN_TABLE[SI+2]
    MOV  BH, 0
    MOV  DL, BOARD[BX]          ; DL = 3a casilla

    ; Caso 1: computadora en la 1a y 2a, la 3a vacia
    CMP  CL, 2
    JNE  WIN_CASE2
    CMP  CH, 2
    JNE  WIN_CASE2
    CMP  DL, 0
    JNE  WIN_CASE2

    MOV  BL, WIN_TABLE[SI+2]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1
    JMP  WIN_LINE_DONE

WIN_CASE2:
    ; Caso 2: computadora en la 1a y 3a, la 2a vacia
    CMP  CL, 2
    JNE  WIN_CASE3
    CMP  DL, 2
    JNE  WIN_CASE3
    CMP  CH, 0
    JNE  WIN_CASE3

    MOV  BL, WIN_TABLE[SI+1]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1
    JMP  WIN_LINE_DONE

WIN_CASE3:
    ; Caso 3: computadora en la 2a y 3a, la 1a vacia
    CMP  CH, 2
    JNE  WIN_LINE_DONE
    CMP  DL, 2
    JNE  WIN_LINE_DONE
    CMP  CL, 0
    JNE  WIN_LINE_DONE

    MOV  BL, WIN_TABLE[SI]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1

WIN_LINE_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
TRY_WIN_LINE ENDP


; ---------------------------------------------------------------------
;  TRY_BLOCK_LINE: intenta bloquear al jugador en una linea
;    Entrada: SI = inicio de la linea en WIN_TABLE.
;    Si el jugador (1) tiene 2 casillas de la linea y la tercera esta
;    vacia, la computadora marca la tercera con 2.
;    Salida: AL = 1 si jugo, AL = 0 si no. No cambia otros registros.
; ---------------------------------------------------------------------
TRY_BLOCK_LINE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AL, 0                  ; por ahora: no jugo

    MOV  BL, WIN_TABLE[SI]
    MOV  BH, 0
    MOV  CL, BOARD[BX]          ; CL = 1a casilla

    MOV  BL, WIN_TABLE[SI+1]
    MOV  BH, 0
    MOV  CH, BOARD[BX]          ; CH = 2a casilla

    MOV  BL, WIN_TABLE[SI+2]
    MOV  BH, 0
    MOV  DL, BOARD[BX]          ; DL = 3a casilla

    ; Caso 1: jugador en la 1a y 2a, la 3a vacia
    CMP  CL, 1
    JNE  CHECK_CASE2
    CMP  CH, 1
    JNE  CHECK_CASE2
    CMP  DL, 0
    JNE  CHECK_CASE2

    MOV  BL, WIN_TABLE[SI+2]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1
    JMP  BLOCK_DONE

CHECK_CASE2:
    ; Caso 2: jugador en la 1a y 3a, la 2a vacia
    CMP  CL, 1
    JNE  CHECK_CASE3
    CMP  DL, 1
    JNE  CHECK_CASE3
    CMP  CH, 0
    JNE  CHECK_CASE3

    MOV  BL, WIN_TABLE[SI+1]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1
    JMP  BLOCK_DONE

CHECK_CASE3:
    ; Caso 3: jugador en la 2a y 3a, la 1a vacia
    CMP  CH, 1
    JNE  BLOCK_DONE
    CMP  DL, 1
    JNE  BLOCK_DONE
    CMP  CL, 0
    JNE  BLOCK_DONE

    MOV  BL, WIN_TABLE[SI]
    MOV  BH, 0
    MOV  BOARD[BX], 2
    MOV  AL, 1

BLOCK_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
TRY_BLOCK_LINE ENDP


; ---------------------------------------------------------------------
;  SHOW_TURN_INDICATOR: muestra de quien es el turno
;    Entrada: AL = 0 (turno del jugador) o 1 (turno de la computadora).
;    No cambia ningun registro.
; ---------------------------------------------------------------------
SHOW_TURN_INDICATOR PROC
    PUSH AX
    PUSH DX

    CMP  AL, 0
    JE   PRINT_PLAYER_TURN

    IMPRIMIR MSG_COMP_TURN
    JMP  TURN_DONE

PRINT_PLAYER_TURN:
    IMPRIMIR MSG_YOUR_TURN

TURN_DONE:
    POP  DX
    POP  AX
    RET
SHOW_TURN_INDICATOR ENDP


; ---------------------------------------------------------------------
;  SHOW_REPLAY_MENU: pantalla de fin de partida
;    Muestra "GAME OVER", el marcador y pregunta si se juega otra vez.
;    Acepta Y/N en mayuscula o minuscula; cualquier otra tecla vuelve
;    a preguntar.
;    Salida: AX = 1 (jugar otra vez) o AX = 0 (salir).
;    Nota: el marcador se muestra con un solo digito (0 a 9).
; ---------------------------------------------------------------------
SHOW_REPLAY_MENU PROC
    PUSH DX

    MOV  AL, GAME_STATE
    MOV  AH, 0
    PUSH AX                     ; guarda el estado de la partida

    IMPRIMIR MSG_GAME_OVER
    IMPRIMIR MSG_SCORE_HDR

    ; Partidas ganadas por el jugador
    IMPRIMIR MSG_PSCORE
    MOV  AL, PLAYER_SCORE
    ADD  AL, 30H                ; numero -> caracter ('0' = 30h)
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h
    CALL PRINT_NEWLINE

    ; Partidas ganadas por la computadora
    IMPRIMIR MSG_CSCORE
    MOV  AL, COMP_SCORE
    ADD  AL, 30H                ; numero -> caracter ('0' = 30h)
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h
    CALL PRINT_NEWLINE

REPLAY_ASK:
    IMPRIMIR MSG_REPLAY_ASK

    MOV  AH, 08h                ; INT 21h/08h: leer tecla sin mostrarla
    INT  21h

    ; Pasar 'y' y 'n' a mayuscula para aceptar las dos formas
    CMP  AL, 'y'
    JNE  CHECK_N_LOWER
    MOV  AL, 'Y'

CHECK_N_LOWER:
    CMP  AL, 'n'
    JNE  CHECK_YES
    MOV  AL, 'N'

CHECK_YES:
    CMP  AL, 'Y'
    JE   WANTS_REPLAY

    CMP  AL, 'N'
    JE   WANTS_QUIT

    ; Cualquier otra tecla: avisar y volver a preguntar
    IMPRIMIR MSG_INVALID_KEY
    JMP  REPLAY_ASK

WANTS_REPLAY:
    IMPRIMIR MSG_REPLAYING

    POP  AX                     ; saca el estado guardado
    POP  DX

    MOV  AX, 1                  ; 1 = jugar otra vez
    RET

WANTS_QUIT:
    IMPRIMIR MSG_GOODBYE

    POP  AX                     ; saca el estado guardado
    POP  DX

    MOV  AX, 0                  ; 0 = salir
    RET

SHOW_REPLAY_MENU ENDP


; ---------------------------------------------------------------------
;  RESET_GAME: prepara una partida nueva
;    Vacia las 9 casillas, pone GAME_STATE = 0 (en curso) y el turno
;    en el jugador. El marcador no se borra. No cambia ningun registro.
; ---------------------------------------------------------------------
RESET_GAME PROC
    PUSH AX
    PUSH BX
    PUSH CX

    MOV  GAME_STATE,    0
    MOV  CURRENT_TURN,  1

    ; Poner las 9 casillas en 0 (vacias)
    MOV  CX, 9
    MOV  BX, 0
    MOV  AL, 0

RESET_LOOP:
    MOV  BH, 0
    MOV  BOARD[BX], AL
    INC  BX
    LOOP RESET_LOOP

    POP  CX
    POP  BX
    POP  AX
    RET
RESET_GAME ENDP


; ---------------------------------------------------------------------
;  ASK_WHO_FIRST: pregunta quien empieza la partida
;    P = jugador (CURRENT_TURN = 1), C = computadora (CURRENT_TURN = 2).
;    Acepta mayuscula o minuscula; cualquier otra tecla vuelve a
;    preguntar. No cambia ningun registro.
; ---------------------------------------------------------------------
ASK_WHO_FIRST PROC
    PUSH AX
    PUSH DX

ASK_FIRST_LOOP:
    IMPRIMIR MSG_WHO_FIRST

    MOV  AH, 08h                ; INT 21h/08h: leer tecla sin mostrarla
    INT  21h

    ; Pasar 'p' y 'c' a mayuscula para aceptar las dos formas
    CMP  AL, 'p'
    JNE  CHECK_C_LOWER
    MOV  AL, 'P'

CHECK_C_LOWER:
    CMP  AL, 'c'
    JNE  CHECK_P
    MOV  AL, 'C'

CHECK_P:
    CMP  AL, 'P'
    JNE  CHECK_C
    MOV  CURRENT_TURN, 1        ; empieza el jugador
    JMP  FIRST_DONE

CHECK_C:
    CMP  AL, 'C'
    JNE  INVALID_FIRST
    MOV  CURRENT_TURN, 2        ; empieza la computadora
    JMP  FIRST_DONE

INVALID_FIRST:
    IMPRIMIR MSG_INVALID_KEY2
    JMP  ASK_FIRST_LOOP

FIRST_DONE:
    CALL PRINT_NEWLINE
    POP  DX
    POP  AX
    RET
ASK_WHO_FIRST ENDP


; ---------------------------------------------------------------------
;  PRINT_NEWLINE: salto de linea (CR + LF). No cambia ningun registro.
; ---------------------------------------------------------------------
PRINT_NEWLINE PROC
    IMPRIMIR MSG_NEWLINE
    RET
PRINT_NEWLINE ENDP


; ---------------------------------------------------------------------
;  LEER_RELOJ: lee la hora del sistema (INT 21h/2Ch)
;    Salida: AX = segundos * 100 + centesimas (0 a 5999).
;    INT 21h/2Ch devuelve CH = hora, CL = minutos, DH = segundos y
;    DL = centesimas de segundo. Solo cambia AX.
; ---------------------------------------------------------------------
LEER_RELOJ PROC
    PUSH CX
    PUSH DX
    MOV  AH, 2Ch
    INT  21h                    ; DH = segundos, DL = centesimas
    MOV  AL, DH
    MOV  AH, 100
    MUL  AH                     ; AX = segundos * 100
    MOV  DH, 0
    ADD  AX, DX                 ; + centesimas
    POP  DX
    POP  CX
    RET
LEER_RELOJ ENDP


; ---------------------------------------------------------------------
;  ESPERAR: detiene el programa un tiempo
;    Entrada: AX = centesimas de segundo a esperar (menos de 6000).
;    Lee el reloj al inicio y lo vuelve a leer hasta que pase el tiempo
;    pedido. Si el minuto cambia en medio (el reloj pasa de 5999 a 0),
;    se suma 6000 para que la resta siga siendo correcta.
;    No cambia ningun registro.
; ---------------------------------------------------------------------
ESPERAR PROC
    PUSH AX
    PUSH BX
    PUSH SI
    MOV  SI, AX                 ; SI = tiempo a esperar
    CALL LEER_RELOJ
    MOV  BX, AX                 ; BX = hora de inicio
ESP_BUCLE:
    CALL LEER_RELOJ             ; AX = hora actual
    SUB  AX, BX                 ; AX = tiempo que ha pasado
    JNC  ESP_COMPARA            ; sin prestamo: el minuto no cambio
    ADD  AX, 6000               ; el minuto cambio: corrige la resta
ESP_COMPARA:
    CMP  AX, SI
    JB   ESP_BUCLE              ; todavia no pasa el tiempo pedido
    POP  SI
    POP  BX
    POP  AX
    RET
ESPERAR ENDP

END

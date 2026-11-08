; =====================================================================
;  G A T O  (Tic-Tac-Toe) - Proyecto 2, EIF205 Arquitectura de Computadoras
;  Universidad Nacional (Costa Rica), 2026 - EMU8086
;  Codigo base: https://github.com/shairaziz/TicTacToe (modificado)
;  Instrucciones y detalles: ver README.md y el informe tecnico.
;
;  Tablero (BOARD): 9 bytes, posiciones 0..8 de izquierda a derecha y
;  de arriba hacia abajo. 0 = vacia, 1 = jugador (X), 2 = computadora (O).
;
;  Flujo de estados del programa:
;
;     MENU PRINCIPAL --1--> PARTIDA (varias rondas) --+--> GAME OVER (0 vidas)
;        ^   |  2: instrucciones      |  P: pausa      +--> VICTORIA (meta)
;        |   3/ESC: salir             |                       |
;        +------- M (desde pausa o pantalla final) <----------+
;                                     R (pantalla final) = partida nueva
;
;  Una PARTIDA esta formada por RONDAS de gato. Ganar una ronda da puntos,
;  empatar da menos puntos y perder quita una vida.
; =====================================================================


; ---------------------------------------------------------------------
;  MACROS
; ---------------------------------------------------------------------

; IMPRIMIR: muestra un texto terminado en '$' (INT 21h/09h) con el
;   color por defecto. Parametro: msg = variable con el texto.
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

; IMPRIMIR_COLOR: muestra un texto terminado en '$' con un color.
;   Parametros: msg = variable con el texto, color = atributo de video.
;   No cambia ningun registro.
IMPRIMIR_COLOR MACRO msg, color
    PUSH BX
    PUSH DX
    LEA  DX, msg
    MOV  BL, color
    CALL PRINT_COLOR
    POP  DX
    POP  BX
ENDM

; IMPRIMIR_NUM: muestra un numero de 16 bits (0 a 65535) en decimal.
;   Parametros: valor = variable DW o constante, color = atributo.
;   No cambia ningun registro.
IMPRIMIR_NUM MACRO valor, color
    PUSH AX
    PUSH BX
    MOV  AX, valor
    MOV  BL, color
    CALL PRINT_NUM
    POP  BX
    POP  AX
ENDM

; LIMPIAR_PANTALLA: borra toda la pantalla y pone el cursor en (0,0).
;   Primero revisa que la pantalla siga en 80x25 (VERIFICAR_MODO); si
;   es asi, borra con BORRAR_ZONA (INT 10h/06h) sin volver a poner el
;   modo de video, para que no parpadee. No cambia ningun registro.
LIMPIAR_PANTALLA MACRO
    PUSH AX
    CALL VERIFICAR_MODO
    POP  AX
    PUSH CX
    PUSH DX
    MOV  CX, 0000h              ; esquina superior izquierda (fila 0, col 0)
    MOV  DX, 184Fh              ; esquina inferior derecha (fila 24, col 79)
    CALL BORRAR_ZONA
    PUSH AX
    PUSH BX
    MOV  AH, 02h                ; cursor a la esquina (fila 0, col 0)
    MOV  BH, 0
    MOV  DX, 0000h
    INT  10h
    POP  BX
    POP  AX
    POP  DX
    POP  CX
ENDM

; POSICIONAR: mueve el cursor a (fila, columna) con INT 10h/02h.
;   Filas 0..24, columnas 0..79. No cambia ningun registro.
POSICIONAR MACRO fila, columna
    PUSH AX
    PUSH BX
    PUSH DX
    MOV  AH, 02h
    MOV  BH, 0                  ; pagina de video 0
    MOV  DH, fila
    MOV  DL, columna
    INT  10h
    POP  DX
    POP  BX
    POP  AX
ENDM

; LEER_TECLA: espera una tecla sin mostrarla (INT 21h/08h).
;   Salida: AL = codigo ASCII de la tecla. Cambia AH.
LEER_TECLA MACRO
    MOV  AH, 08h
    INT  21h
ENDM

; MAYUSCULA: si AL es una letra minuscula ('a'..'z') la pasa a
;   mayuscula. Sirve para aceptar teclas en mayuscula o minuscula.
MAYUSCULA MACRO
    LOCAL fin_may
    CMP  AL, 'a'
    JB   fin_may
    CMP  AL, 'z'
    JA   fin_may
    SUB  AL, 20h                ; 'a' (61h) - 20h = 'A' (41h)
fin_may:
ENDM

; SONIDO: hace un "beep" mandando el caracter BEL (07h) a la pantalla.
;   No cambia ningun registro.
SONIDO MACRO
    PUSH AX
    PUSH DX
    MOV  DL, 07h
    MOV  AH, 02h
    INT  21h
    POP  DX
    POP  AX
ENDM


; ---------------------------------------------------------------------
;  CONSTANTES
; ---------------------------------------------------------------------

; Tiempo que la computadora "piensa" antes de jugar, en centesimas de
; segundo (100 = 1 segundo, 50 = medio segundo). Debe ser menor que 6000.
RETRASO_CPU     EQU 50

; Reglas de la partida
VIDAS_INICIALES EQU 3           ; vidas al empezar (perder una ronda quita 1)
PUNTOS_GANAR    EQU 100         ; puntos por ganar una ronda
PUNTOS_EMPATE   EQU 25          ; puntos por empatar una ronda
PUNTOS_META     EQU 500         ; puntos para ganar la partida (VICTORIA)

; Colores (atributo de video = fondo * 16 + texto; fondo negro = 0)
C_TITULO        EQU 0Eh         ; amarillo
C_MARCO         EQU 09h         ; azul claro: lineas del tablero
C_NUMERO        EQU 08h         ; gris oscuro: casillas vacias, vidas perdidas
C_JUGADOR       EQU 0Bh         ; celeste: fichas X
C_COMPU         EQU 0Dh         ; magenta claro: fichas O
C_TEXTO         EQU 0Fh         ; blanco brillante
C_INFO          EQU 07h         ; gris claro
C_BIEN          EQU 0Ah         ; verde claro: ganar
C_MAL           EQU 0Ch         ; rojo claro: perder, errores
C_VIDA          EQU 0Ch         ; rojo claro: corazones de vida

CORAZON         EQU 03h         ; caracter ASCII del corazon
BLOQUE          EQU 0DBh        ; caracter ASCII del bloque solido

; Memoria de video del modo texto 80x25 a color
VIDEO_SEG       EQU 0B800h      ; segmento de la memoria de video
COLUMNAS        EQU 80          ; caracteres por fila

; Fila donde empieza la zona de mensajes (debajo del tablero)
FILA_MENSAJES   EQU 9


.MODEL SMALL
.STACK 100H


; =====================================================================
;  SEGMENTO DE DATOS
;  Alineacion: el segmento empieza en un limite de parrafo (direccion
;  multiplo de 16). Por eso todas las variables de 16 bits (DW) van
;  primero: quedan en direcciones pares (0, 2, 4, ...) y el 8086 las
;  lee en un solo ciclo de bus. Si una DW quedara en direccion impar,
;  el 8086 necesitaria dos accesos a memoria para leerla.
; =====================================================================
.DATA

    ; --- Variables de 16 bits (direcciones pares) ---
    PUNTOS          DW  0           ; puntaje acumulado de la partida
    HIGH_SCORE      DW  0           ; marcador maximo (dura mientras el programa este abierto)
    RONDA           DW  0           ; numero de ronda actual
    GANADAS         DW  0           ; rondas ganadas por el jugador
    PERDIDAS        DW  0           ; rondas ganadas por la computadora
    EMPATES         DW  0           ; rondas empatadas

    ; Posicion de cada casilla en la memoria de video: (fila*80+col)*2.
    ; Las casillas estan en las filas 4, 6 y 8 y en las columnas
    ; 35, 39 y 43 (ver DIBUJAR_RONDA).
    TABLA_CELDAS    DW  710, 718, 726       ; fila 4: casillas 1, 2, 3
                    DW  1030, 1038, 1046    ; fila 6: casillas 4, 5, 6
                    DW  1350, 1358, 1366    ; fila 8: casillas 7, 8, 9

    ; --- Variables de 8 bits ---
    ; Tablero de 9 casillas (ver "Tablero" arriba)
    BOARD           DB  9 DUP(0)

    ; Turno actual: 1 = jugador, 2 = computadora
    CURRENT_TURN    DB  1

    ; Estado de la ronda: 0 = en curso, 1 = gano el jugador,
    ; 2 = gano la computadora, 3 = empate
    GAME_STATE      DB  0

    ; Vidas que le quedan al jugador
    VIDAS           DB  VIDAS_INICIALES

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

    ; Orden en que la computadora prefiere las casillas cuando no puede
    ; ganar ni bloquear: centro, esquinas y por ultimo los lados
    PREFERENCIA     DB  4, 0,2,6,8, 1,3,5,7

    ; --- Textos generales ---
    MSG_NEWLINE     DB  0Dh, 0Ah, '$'      ; salto de linea (CR + LF)
    MSG_ADIOS       DB  'Gracias por jugar GATO! Hasta pronto.',0Dh,0Ah,'$'

    ; --- Menu principal ('#' se dibuja como un bloque solido) ---
    MSG_LOGO        DB  '                   ####    ###   #####   ### ',0Dh,0Ah
                    DB  '                  #       #   #    #    #   #',0Dh,0Ah
                    DB  '                  #  ###  #####    #    #   #',0Dh,0Ah
                    DB  '                  #    #  #   #    #    #   #',0Dh,0Ah
                    DB  '                   ####   #   #    #     ### ',0Dh,0Ah,'$'
    MSG_SUBTITULO   DB  0Dh,0Ah,'               Tic-Tac-Toe en ensamblador 8086 - EIF205',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_M_RECORD    DB  '                        Record actual: $'
    MSG_OPCIONES    DB  0Dh,0Ah,0Dh,0Ah
                    DB  '                        1. Jugar',0Dh,0Ah
                    DB  '                        2. Instrucciones',0Dh,0Ah
                    DB  '                        3. Salir',0Dh,0Ah,0Dh,0Ah
                    DB  '                        Elija una opcion: $'

    ; --- Instrucciones ---
    MSG_I_TITULO    DB  0Dh,0Ah,'  ========  INSTRUCCIONES  ========',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_I_TEXTO     DB  '  Usted juega con la X contra la computadora (O).',0Dh,0Ah
                    DB  '  Gana la ronda quien complete una fila, columna o diagonal.',0Dh,0Ah,0Dh,0Ah
                    DB  '  Casillas:   1 | 2 | 3      Teclas:',0Dh,0Ah
                    DB  '             ---+---+---       1 a 9  marcar casilla',0Dh,0Ah
                    DB  '              4 | 5 | 6        P      pausa',0Dh,0Ah
                    DB  '             ---+---+---       J / C  quien empieza',0Dh,0Ah
                    DB  '              7 | 8 | 9',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_I_GANAR     DB  '  - Ganar una ronda:   +$'
    MSG_I_EMPATE    DB  '  - Empatar una ronda: +$'
    MSG_I_PUNTOS    DB  ' puntos',0Dh,0Ah,'$'
    MSG_I_PERDER    DB  '  - Perder una ronda:  -1 vida (empieza con $'
    MSG_I_VIDAS     DB  ' vidas)',0Dh,0Ah,'$'
    MSG_I_META1     DB  0Dh,0Ah,'  VICTORIA: llegue a $'
    MSG_I_META2     DB  ' puntos.   GAME OVER: se queda sin vidas.',0Dh,0Ah,'$'
    MSG_TECLA       DB  0Dh,0Ah,'  Presione cualquier tecla para continuar...$'

    ; --- Pantalla de juego ---
    MSG_TITULO      DB  '=====  G A T O  =====$'
    MSG_E_PUNTOS    DB  'Puntos: $'
    MSG_E_VIDAS     DB  '   Vidas: $'
    MSG_E_RECORD    DB  '   Record: $'
    MSG_E_RONDA     DB  '   Ronda: $'
    MSG_E_META      DB  '   Meta: $'
    MSG_INICIO_FILA DB  35 DUP(' '), '$'                       ; sangria de cada fila
    MSG_BAR         DB  ' | $'                                  ; separador de columnas
    MSG_FILA        DB  34 DUP(' '), '---+---+---', 0Dh,0Ah,'$' ; separador de filas

    ; --- Mensajes de la ronda ---
    MSG_YOUR_TURN   DB  0Dh,0Ah,'  >> TU TURNO: elija una casilla (1-9)    P = pausa',0Dh,0Ah,'$'
    MSG_COMP_TURN   DB  0Dh,0Ah,'  >> LA COMPUTADORA ESTA PENSANDO...',0Dh,0Ah,'$'
    MSG_INVALID     DB  0Dh,0Ah,'  Jugada invalida! Use 1-9 en una casilla vacia.$'
    MSG_WHO_FIRST   DB  0Dh,0Ah,'  Quien empieza?   J = Jugador   C = Computadora: $'
    MSG_INVALID_KEY2 DB 0Dh,0Ah,'  Tecla invalida. Presione J o C.$'
    MSG_GANA_RONDA  DB  0Dh,0Ah,'  GANASTE LA RONDA!  +$'
    MSG_EMPATE_RONDA DB 0Dh,0Ah,'  EMPATE!  +$'
    MSG_PUNTOS_TXT  DB  ' puntos$'
    MSG_PIERDE_RONDA DB 0Dh,0Ah,'  LA COMPUTADORA GANA LA RONDA.  -1 vida$'
    MSG_SIGUIENTE   DB  0Dh,0Ah,0Dh,0Ah,'  Presione cualquier tecla para la siguiente ronda...$'

    ; --- Pausa ---
    MSG_PAUSA       DB  '                   ===============================',0Dh,0Ah
                    DB  '                         JUEGO  EN  PAUSA',0Dh,0Ah
                    DB  '                   ===============================',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_PAUSA_OPC   DB  '                     P = continuar la partida',0Dh,0Ah
                    DB  '                     M = volver al menu principal',0Dh,0Ah
                    DB  '                         (se pierde la partida)',0Dh,0Ah,'$'

    ; --- Pantallas finales ---
    MSG_GAMEOVER    DB  '              ##########################################',0Dh,0Ah
                    DB  '                       G A M E      O V E R',0Dh,0Ah
                    DB  '                       Te quedaste sin vidas',0Dh,0Ah
                    DB  '              ##########################################',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_VICTORIA    DB  '              ##########################################',0Dh,0Ah
                    DB  '                    V I C T O R I A  ! ! !',0Dh,0Ah
                    DB  '                     Llegaste a la meta de puntos',0Dh,0Ah
                    DB  '              ##########################################',0Dh,0Ah,0Dh,0Ah,'$'
    MSG_F_PUNTOS    DB  '                    Puntaje final  : $'
    MSG_F_RONDAS    DB  0Dh,0Ah,'                    Rondas jugadas : $'
    MSG_F_GANADAS   DB  0Dh,0Ah,'                    Ganadas        : $'
    MSG_F_PERDIDAS  DB  0Dh,0Ah,'                    Perdidas       : $'
    MSG_F_EMPATES   DB  0Dh,0Ah,'                    Empates        : $'
    MSG_F_RECORD    DB  0Dh,0Ah,0Dh,0Ah,'                    Record         : $'
    MSG_NUEVO_RECORD DB 0Dh,0Ah,0Dh,0Ah,'                    *** NUEVO RECORD! ***$'
    MSG_FINAL_OPC   DB  0Dh,0Ah,0Dh,0Ah,'          R = jugar otra partida      M = menu principal: $'


; =====================================================================
;  SEGMENTO DE CODIGO
; =====================================================================
.CODE

; ---------------------------------------------------------------------
;  MAIN: programa principal y maquina de estados del juego
;    1. Muestra el menu principal.
;    2. Al elegir "Jugar" empieza una partida nueva (puntos, vidas).
;    3. Cada ronda: tablero vacio, se pregunta quien empieza y se
;       alternan los turnos hasta que alguien gana o hay empate.
;    4. Al final de la ronda se suman puntos o se quita una vida. Si
;       se acabaron las vidas -> GAME OVER; si se llego a la meta ->
;       VICTORIA; si no, sigue otra ronda.
;    5. Desde la pantalla final se puede reiniciar o volver al menu,
;       sin reiniciar el emulador.
; ---------------------------------------------------------------------
MAIN PROC
    MOV  AX, @DATA              ; DS apunta al segmento de datos
    MOV  DS, AX

    MOV  AX, 0003h              ; INT 10h/00h: modo texto 80x25 a color
    INT  10h                    ; (solo una vez, al iniciar)

; --- Estado: MENU PRINCIPAL ---
MENU_INICIO:
    CALL MENU_PRINCIPAL         ; AL = 1 (jugar) o 0 (salir)
    CMP  AL, 1
    JE   INICIO_PARTIDA
    JMP  SALIR_JUEGO

; --- Estado: PARTIDA NUEVA ---
INICIO_PARTIDA:
    CALL NUEVO_JUEGO            ; puntos en 0, vidas completas

; --- Cada ronda empieza aqui ---
NUEVA_RONDA:
    CALL RESET_GAME             ; tablero vacio, ronda + 1
    CALL DIBUJAR_RONDA          ; pantalla completa de la ronda
    CALL ASK_WHO_FIRST
    CALL DRAW_BOARD             ; borra la pregunta

GAME_LOOP:
    ; Si la ronda ya termino (GAME_STATE distinto de 0), ver resultado
    CMP  GAME_STATE, 0
    JE   VER_TURNO
    JMP  SHOW_RESULT

VER_TURNO:
    CMP  CURRENT_TURN, 1
    JE   DO_PLAYER_TURN
    JMP  DO_COMPUTER_TURN

; --- Turno del jugador ---
DO_PLAYER_TURN:
    MOV  AL, 0                  ; 0 = mostrar "TU TURNO"
    CALL SHOW_TURN_INDICATOR

    LEER_TECLA                  ; AL = tecla
    MAYUSCULA

    ; P = pausa
    CMP  AL, 'P'
    JNE  NO_PAUSA
    CALL PAUSA                  ; AL = 0 (continuar) o 1 (ir al menu)
    CMP  AL, 1
    JNE  REANUDAR
    JMP  MENU_INICIO
REANUDAR:
    CALL DIBUJAR_RONDA          ; vuelve a mostrar toda la pantalla
    JMP  GAME_LOOP

NO_PAUSA:
    ; Convertir el caracter '1'..'9' en la posicion 0..8 del tablero.
    ; Si la tecla es menor que '1' la resta "da la vuelta" y queda un
    ; numero grande, asi que una sola comparacion sin signo (JA) sirve
    ; para los dos limites.
    MOV  BL, AL
    SUB  BL, '1'
    CMP  BL, 8
    JA   INVALID_MOVE

    ; Casilla ocupada: jugada invalida
    MOV  BH, 0
    CMP  BOARD[BX], 0
    JNE  INVALID_MOVE

    ; Jugada valida: marcar la casilla con 1 (X)
    MOV  BOARD[BX], 1
    CALL DRAW_BOARD
    CALL CHECK_WIN_DRAW         ; actualiza GAME_STATE

    MOV  CURRENT_TURN, 2        ; ahora le toca a la computadora
    JMP  GAME_LOOP

INVALID_MOVE:
    SONIDO
    CALL DRAW_BOARD             ; borra los mensajes anteriores
    IMPRIMIR_COLOR MSG_INVALID, C_MAL
    JMP  GAME_LOOP              ; vuelve a pedir la jugada

; --- Turno de la computadora ---
DO_COMPUTER_TURN:
    MOV  AL, 1                  ; 1 = mostrar "COMPUTADORA PENSANDO"
    CALL SHOW_TURN_INDICATOR

    MOV  AX, RETRASO_CPU        ; pausa mientras se muestra el mensaje
    CALL ESPERAR

    CALL COMPUTER_MOVE          ; elige y marca una casilla con 2 (O)
    CALL DRAW_BOARD
    CALL CHECK_WIN_DRAW         ; actualiza GAME_STATE

    MOV  CURRENT_TURN, 1        ; ahora le toca al jugador
    JMP  GAME_LOOP

; --- Fin de la ronda ---
SHOW_RESULT:
    CALL FIN_RONDA              ; AL = 0 (sigue), 1 (game over), 2 (victoria)
    CMP  AL, 0
    JNE  FIN_PARTIDA

    IMPRIMIR_COLOR MSG_SIGUIENTE, C_INFO
    LEER_TECLA
    JMP  NUEVA_RONDA

; --- Estado: GAME OVER o VICTORIA ---
FIN_PARTIDA:
    CALL PANTALLA_FINAL         ; AL = 1 (otra partida) o 0 (menu)
    CMP  AL, 1
    JNE  VOLVER_MENU
    JMP  INICIO_PARTIDA
VOLVER_MENU:
    JMP  MENU_INICIO

; --- Salir al sistema ---
SALIR_JUEGO:
    LIMPIAR_PANTALLA
    IMPRIMIR_COLOR MSG_ADIOS, C_TITULO
    MOV  AX, 4C00H              ; INT 21h/4Ch: terminar el programa
    INT  21H

MAIN ENDP


; ---------------------------------------------------------------------
;  MENU_PRINCIPAL: pantalla de inicio
;    Muestra el logo, el record y las opciones 1 (jugar),
;    2 (instrucciones) y 3 o ESC (salir).
;    Salida: AL = 1 (jugar) o AL = 0 (salir). Cambia AH.
; ---------------------------------------------------------------------
MENU_PRINCIPAL PROC
MP_DIBUJAR:
    LIMPIAR_PANTALLA
    POSICIONAR 3, 0
    IMPRIMIR_COLOR MSG_LOGO, C_TITULO
    IMPRIMIR_COLOR MSG_SUBTITULO, C_INFO
    IMPRIMIR_COLOR MSG_M_RECORD, C_BIEN
    IMPRIMIR_NUM   HIGH_SCORE, C_BIEN
    IMPRIMIR_COLOR MSG_OPCIONES, C_TEXTO

MP_LEER:
    LEER_TECLA
    CMP  AL, '1'
    JE   MP_JUGAR
    CMP  AL, '2'
    JE   MP_INSTRUCCIONES
    CMP  AL, '3'
    JE   MP_SALIR
    CMP  AL, 1Bh                ; ESC
    JE   MP_SALIR
    SONIDO                      ; otra tecla: aviso y vuelve a leer
    JMP  MP_LEER

MP_INSTRUCCIONES:
    CALL MOSTRAR_INSTRUCCIONES
    JMP  MP_DIBUJAR             ; al volver se dibuja el menu de nuevo

MP_JUGAR:
    MOV  AL, 1
    RET

MP_SALIR:
    MOV  AL, 0
    RET
MENU_PRINCIPAL ENDP


; ---------------------------------------------------------------------
;  MOSTRAR_INSTRUCCIONES: explica las reglas y espera una tecla.
;    Los valores de puntos, vidas y meta se toman de las constantes,
;    asi que si se cambian arriba el texto se actualiza solo.
;    Cambia AX (por la lectura de la tecla).
; ---------------------------------------------------------------------
MOSTRAR_INSTRUCCIONES PROC
    LIMPIAR_PANTALLA
    IMPRIMIR_COLOR MSG_I_TITULO, C_TITULO
    IMPRIMIR_COLOR MSG_I_TEXTO, C_TEXTO

    IMPRIMIR_COLOR MSG_I_GANAR, C_BIEN
    IMPRIMIR_NUM   PUNTOS_GANAR, C_BIEN
    IMPRIMIR_COLOR MSG_I_PUNTOS, C_BIEN

    IMPRIMIR_COLOR MSG_I_EMPATE, C_TITULO
    IMPRIMIR_NUM   PUNTOS_EMPATE, C_TITULO
    IMPRIMIR_COLOR MSG_I_PUNTOS, C_TITULO

    IMPRIMIR_COLOR MSG_I_PERDER, C_MAL
    IMPRIMIR_NUM   VIDAS_INICIALES, C_MAL
    IMPRIMIR_COLOR MSG_I_VIDAS, C_MAL

    IMPRIMIR_COLOR MSG_I_META1, C_TEXTO
    IMPRIMIR_NUM   PUNTOS_META, C_TEXTO
    IMPRIMIR_COLOR MSG_I_META2, C_TEXTO

    IMPRIMIR_COLOR MSG_TECLA, C_INFO
    LEER_TECLA
    RET
MOSTRAR_INSTRUCCIONES ENDP


; ---------------------------------------------------------------------
;  NUEVO_JUEGO: prepara una partida nueva
;    Puntos, ronda y contadores en 0; vidas en VIDAS_INICIALES.
;    El High Score no se borra. No cambia ningun registro.
; ---------------------------------------------------------------------
NUEVO_JUEGO PROC
    MOV  PUNTOS,   0
    MOV  RONDA,    0
    MOV  GANADAS,  0
    MOV  PERDIDAS, 0
    MOV  EMPATES,  0
    MOV  VIDAS,    VIDAS_INICIALES
    RET
NUEVO_JUEGO ENDP


; ---------------------------------------------------------------------
;  RESET_GAME: prepara una ronda nueva
;    Vacia las 9 casillas, pone GAME_STATE = 0 (en curso), el turno
;    en el jugador y suma 1 al numero de ronda. No cambia ningun
;    registro.
; ---------------------------------------------------------------------
RESET_GAME PROC
    PUSH AX
    PUSH BX
    PUSH CX

    MOV  GAME_STATE,    0
    MOV  CURRENT_TURN,  1
    INC  RONDA

    ; Poner las 9 casillas en 0 (vacias)
    MOV  CX, 9
    MOV  BX, 0
    MOV  AL, 0

RESET_LOOP:
    MOV  BOARD[BX], AL
    INC  BX
    LOOP RESET_LOOP

    POP  CX
    POP  BX
    POP  AX
    RET
RESET_GAME ENDP


; ---------------------------------------------------------------------
;  ASK_WHO_FIRST: pregunta quien empieza la ronda
;    J = jugador (CURRENT_TURN = 1), C = computadora (CURRENT_TURN = 2).
;    Acepta mayuscula o minuscula; cualquier otra tecla vuelve a
;    preguntar. No cambia ningun registro.
; ---------------------------------------------------------------------
ASK_WHO_FIRST PROC
    PUSH AX

ASK_FIRST_LOOP:
    IMPRIMIR_COLOR MSG_WHO_FIRST, C_TEXTO
    LEER_TECLA
    MAYUSCULA

    CMP  AL, 'J'
    JNE  CHECK_C
    MOV  CURRENT_TURN, 1        ; empieza el jugador
    JMP  FIRST_DONE

CHECK_C:
    CMP  AL, 'C'
    JNE  INVALID_FIRST
    MOV  CURRENT_TURN, 2        ; empieza la computadora
    JMP  FIRST_DONE

INVALID_FIRST:
    SONIDO
    IMPRIMIR_COLOR MSG_INVALID_KEY2, C_MAL
    JMP  ASK_FIRST_LOOP

FIRST_DONE:
    POP  AX
    RET
ASK_WHO_FIRST ENDP


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

    MOV  BL, WIN_TABLE[SI+1]
    MOV  AH, BOARD[BX]          ; AH = valor de la 2a casilla

    CMP  AL, AH                 ; 1a igual a 2a?
    JNE  NEXT_LINE

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
    MOV  BX, 0

DRAW_LOOP:
    CMP  BOARD[BX], 0
    JE   WIN_DONE               ; hay una casilla vacia: no es empate
    INC  BX
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
;  DIBUJAR_RONDA: borra la pantalla y dibuja titulo, barra de estado
;    y tablero completo (con las lineas), todo a color. Se usa solo al
;    empezar una ronda o al volver de la pausa; en cada jugada basta
;    con DRAW_BOARD, que es mucho mas rapido. Las casillas vacias muestran su numero
;    (1-9) en gris, las del jugador una X celeste y las de la
;    computadora una O magenta. No cambia ningun registro.
; ---------------------------------------------------------------------
DIBUJAR_RONDA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    LIMPIAR_PANTALLA
    POSICIONAR 0, 29
    IMPRIMIR_COLOR MSG_TITULO, C_TITULO
    CALL MOSTRAR_ESTADO         ; barra de estado en la fila 2
    POSICIONAR 4, 0             ; el tablero empieza en la fila 4

    MOV  CX, 9                  ; 9 casillas
    MOV  SI, 0                  ; SI = posicion actual (0..8)

DRAW_CELL:
    ; Al inicio de cada fila (posiciones 0, 3 y 6) va la sangria
    CMP  SI, 0
    JE   DB_SANGRIA
    CMP  SI, 3
    JE   DB_SANGRIA
    CMP  SI, 6
    JNE  DB_FICHA
DB_SANGRIA:
    IMPRIMIR MSG_INICIO_FILA

DB_FICHA:
    MOV  AL, BOARD[SI]          ; valor de la casilla

    CMP  AL, 0
    JE   PRINT_NUMBER
    CMP  AL, 1
    JE   PRINT_X

PRINT_O:                        ; valor 2: computadora
    MOV  AL, 'O'
    MOV  BL, C_COMPU
    JMP  PRINT_CHAR

PRINT_X:                        ; valor 1: jugador
    MOV  AL, 'X'
    MOV  BL, C_JUGADOR
    JMP  PRINT_CHAR

PRINT_NUMBER:                   ; valor 0: vacia, muestra posicion + 1
    MOV  AX, SI
    ADD  AL, '1'
    MOV  BL, C_NUMERO

PRINT_CHAR:
    CALL PUT_CHAR_COLOR         ; dibuja AL con el color BL

    ; Despues de las posiciones 2 y 5 termina una fila: dibujar la raya
    CMP  SI, 2
    JE   ROW_END
    CMP  SI, 5
    JE   ROW_END
    CMP  SI, 8                  ; la posicion 8 es la ultima casilla
    JE   BOARD_DONE_ROW

    IMPRIMIR_COLOR MSG_BAR, C_MARCO     ; separador entre columnas
    JMP  NEXT_CELL

ROW_END:
    CALL PRINT_NEWLINE
    IMPRIMIR_COLOR MSG_FILA, C_MARCO    ; raya entre filas
    JMP  NEXT_CELL

BOARD_DONE_ROW:
    CALL PRINT_NEWLINE

NEXT_CELL:
    INC  SI
    LOOP DRAW_CELL

    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
DIBUJAR_RONDA ENDP


; ---------------------------------------------------------------------
;  DRAW_BOARD: actualiza el tablero despues de cada jugada (rapido)
;    Las lineas del tablero no cambian, asi que solo se reescriben las
;    9 casillas directo en la memoria de video (usando TABLA_CELDAS) y
;    se borra la zona de mensajes. El cursor queda al inicio de esa
;    zona. No cambia ningun registro.
; ---------------------------------------------------------------------
DRAW_BOARD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES

    ; Si la pantalla cambio de tamano (por ejemplo, al maximizar la
    ; ventana del emulador), se vuelve a 80x25 y se redibuja todo
    CALL VERIFICAR_MODO         ; AL = 1 si tuvo que reiniciar el modo
    CMP  AL, 1
    JNE  DB2_INICIO
    CALL DIBUJAR_RONDA
DB2_INICIO:
    MOV  AX, VIDEO_SEG
    MOV  ES, AX                 ; ES = memoria de video
    MOV  SI, 0                  ; SI = casilla (0..8)
    MOV  CX, 9

DB2_CASILLA:
    MOV  AL, BOARD[SI]
    CMP  AL, 0
    JE   DB2_NUMERO
    CMP  AL, 1
    JE   DB2_X
    MOV  AL, 'O'                ; computadora
    MOV  AH, C_COMPU
    JMP  DB2_PONER
DB2_X:
    MOV  AL, 'X'                ; jugador
    MOV  AH, C_JUGADOR
    JMP  DB2_PONER
DB2_NUMERO:
    MOV  AX, SI                 ; vacia: numero de la casilla
    ADD  AL, '1'
    MOV  AH, C_NUMERO
DB2_PONER:
    MOV  BX, SI
    SHL  BX, 1                  ; TABLA_CELDAS es de palabras (2 bytes)
    MOV  DI, TABLA_CELDAS[BX]
    MOV  ES:[DI], AX            ; caracter y color de la casilla
    INC  SI
    LOOP DB2_CASILLA

    ; Borrar la zona de mensajes (filas 9 a 24)
    MOV  CH, FILA_MENSAJES
    MOV  CL, 0
    MOV  DX, 184Fh
    CALL BORRAR_ZONA
    POSICIONAR FILA_MENSAJES, 0

    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DRAW_BOARD ENDP


; ---------------------------------------------------------------------
;  VERIFICAR_MODO: se asegura de que la pantalla sea de 80 columnas
;    El dibujo rapido escribe directo en la memoria de video suponiendo
;    80 columnas. EMU8086 cambia el tamano de la pantalla si se agranda
;    o maximiza su ventana, asi que se pregunta el ancho actual con
;    INT 10h/0Fh (AH = columnas). Si no es 80, se vuelve a poner el
;    modo texto 80x25 (INT 10h, AX = 0003h), que ademas borra todo.
;    Salida: AL = 1 si se reinicio el modo, AL = 0 si no hizo falta.
;    Cambia AH.
; ---------------------------------------------------------------------
VERIFICAR_MODO PROC
    PUSH BX                     ; INT 10h/0Fh devuelve BH = pagina
    MOV  AH, 0Fh
    INT  10h                    ; AH = columnas, AL = modo actual
    CMP  AH, COLUMNAS
    JE   VM_BIEN
    MOV  AX, 0003h              ; modo texto 80x25 a color
    INT  10h
    MOV  AL, 1
    JMP  VM_FIN
VM_BIEN:
    MOV  AL, 0
VM_FIN:
    POP  BX
    RET
VERIFICAR_MODO ENDP


; ---------------------------------------------------------------------
;  BORRAR_ZONA: borra un rectangulo de la pantalla con INT 10h/06h
;    (scroll con AL = 0 limpia toda la ventana de una vez).
;    Entrada: CH, CL = fila, columna de la esquina superior izquierda;
;             DH, DL = fila, columna de la esquina inferior derecha.
;    No cambia ningun registro.
; ---------------------------------------------------------------------
BORRAR_ZONA PROC
    PUSH AX
    PUSH BX
    MOV  AX, 0600h              ; AH = 06h, AL = 0 (borrar todo)
    MOV  BH, 07h                ; color de lo borrado: gris sobre negro
    INT  10h
    POP  BX
    POP  AX
    RET
BORRAR_ZONA ENDP


; ---------------------------------------------------------------------
;  MOSTRAR_ESTADO: dibuja la barra de estado en la fila 2:
;      Puntos: N   Vidas: (corazones)   Record: N   Ronda: N   Meta: N
;    Las vidas que quedan se ven como corazones rojos y las perdidas
;    como corazones grises. Guarda la posicion del cursor y la
;    devuelve al terminar, asi se puede llamar en cualquier momento.
;    No cambia ningun registro.
; ---------------------------------------------------------------------
MOSTRAR_ESTADO PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 03h                ; INT 10h/03h: DH,DL = fila,columna actual
    MOV  BH, 0
    INT  10h
    PUSH DX                     ; guarda la posicion del cursor

    POSICIONAR 2, 2
    IMPRIMIR_COLOR MSG_E_PUNTOS, C_INFO
    IMPRIMIR_NUM   PUNTOS, C_TEXTO
    IMPRIMIR_COLOR MSG_E_VIDAS, C_INFO

    ; Un corazon por cada vida inicial: rojo si la vida sigue, gris si
    ; ya se perdio. DL cuenta 1, 2, 3...
    MOV  CX, VIDAS_INICIALES
    MOV  DL, 0
ME_CORAZON:
    INC  DL
    MOV  AL, CORAZON
    MOV  BL, C_VIDA
    CMP  DL, VIDAS
    JBE  ME_PINTAR              ; DL <= VIDAS: vida que sigue
    MOV  BL, C_NUMERO           ; vida perdida
ME_PINTAR:
    CALL PUT_CHAR_COLOR
    LOOP ME_CORAZON

    IMPRIMIR_COLOR MSG_E_RECORD, C_INFO
    IMPRIMIR_NUM   HIGH_SCORE, C_TEXTO
    IMPRIMIR_COLOR MSG_E_RONDA, C_INFO
    IMPRIMIR_NUM   RONDA, C_TEXTO
    IMPRIMIR_COLOR MSG_E_META, C_INFO
    IMPRIMIR_NUM   PUNTOS_META, C_TEXTO

    POP  DX                     ; devuelve el cursor a donde estaba
    MOV  AH, 02h
    MOV  BH, 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
MOSTRAR_ESTADO ENDP


; ---------------------------------------------------------------------
;  COMPUTER_MOVE: la computadora elige su jugada y la marca con 2 (O)
;    1. Si puede ganar completando una linea, la completa.
;    2. Si no, si el jugador esta por ganar, lo bloquea.
;    3. Si no, toma la primera casilla libre segun PREFERENCIA
;       (centro, luego esquinas, luego lados).
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

    ; 3) Tomar la primera casilla libre en el orden de PREFERENCIA
    MOV  CX, 9
    MOV  SI, 0
    MOV  BH, 0

PREF_SCAN:
    MOV  BL, PREFERENCIA[SI]    ; BX = casilla candidata
    CMP  BOARD[BX], 0
    JE   PREF_PLACE
    INC  SI
    LOOP PREF_SCAN
    JMP  COMPUTER_DONE          ; no hay casillas vacias

PREF_PLACE:
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
    CMP  AL, 0
    JE   PRINT_PLAYER_TURN

    IMPRIMIR_COLOR MSG_COMP_TURN, C_COMPU
    RET

PRINT_PLAYER_TURN:
    IMPRIMIR_COLOR MSG_YOUR_TURN, C_JUGADOR
    RET
SHOW_TURN_INDICATOR ENDP


; ---------------------------------------------------------------------
;  FIN_RONDA: aplica el resultado de la ronda (GAME_STATE)
;    1 = gano el jugador  -> +PUNTOS_GANAR
;    2 = gano la compu    -> -1 vida
;    3 = empate           -> +PUNTOS_EMPATE
;    Muestra el resultado, actualiza la barra de estado y decide como
;    sigue la partida.
;    Salida: AL = 0 (otra ronda), 1 (GAME OVER: sin vidas) o
;            2 (VICTORIA: se llego a PUNTOS_META). Cambia AH.
; ---------------------------------------------------------------------
FIN_RONDA PROC
    MOV  AL, GAME_STATE
    CMP  AL, 1
    JE   FR_GANA
    CMP  AL, 2
    JE   FR_PIERDE

    ; GAME_STATE = 3: empate
    INC  EMPATES
    ADD  PUNTOS, PUNTOS_EMPATE
    IMPRIMIR_COLOR MSG_EMPATE_RONDA, C_TITULO
    IMPRIMIR_NUM   PUNTOS_EMPATE, C_TITULO
    IMPRIMIR_COLOR MSG_PUNTOS_TXT, C_TITULO
    JMP  FR_ESTADO

FR_GANA:
    INC  GANADAS
    ADD  PUNTOS, PUNTOS_GANAR
    SONIDO
    IMPRIMIR_COLOR MSG_GANA_RONDA, C_BIEN
    IMPRIMIR_NUM   PUNTOS_GANAR, C_BIEN
    IMPRIMIR_COLOR MSG_PUNTOS_TXT, C_BIEN
    JMP  FR_ESTADO

FR_PIERDE:
    INC  PERDIDAS
    DEC  VIDAS
    SONIDO
    IMPRIMIR_COLOR MSG_PIERDE_RONDA, C_MAL

FR_ESTADO:
    CALL MOSTRAR_ESTADO         ; puntos y vidas nuevos en la barra

    ; Decidir el siguiente estado
    MOV  AL, 1                  ; 1 = GAME OVER
    CMP  VIDAS, 0
    JE   FR_FIN
    MOV  AL, 2                  ; 2 = VICTORIA
    CMP  PUNTOS, PUNTOS_META
    JAE  FR_FIN
    MOV  AL, 0                  ; 0 = sigue otra ronda
FR_FIN:
    RET
FIN_RONDA ENDP


; ---------------------------------------------------------------------
;  PAUSA: congela la partida hasta que el jugador decida
;    Muestra la pantalla de pausa. P = continuar, M = menu principal.
;    Salida: AL = 0 (continuar) o AL = 1 (menu). Cambia AH.
; ---------------------------------------------------------------------
PAUSA PROC
    LIMPIAR_PANTALLA
    POSICIONAR 8, 0
    IMPRIMIR_COLOR MSG_PAUSA, C_TITULO
    IMPRIMIR_COLOR MSG_PAUSA_OPC, C_TEXTO

PA_LEER:
    LEER_TECLA
    MAYUSCULA
    CMP  AL, 'P'
    JE   PA_CONTINUAR
    CMP  AL, 'M'
    JE   PA_MENU
    JMP  PA_LEER                ; otra tecla: se ignora

PA_CONTINUAR:
    MOV  AL, 0
    RET

PA_MENU:
    MOV  AL, 1
    RET
PAUSA ENDP


; ---------------------------------------------------------------------
;  PANTALLA_FINAL: pantalla de GAME OVER o de VICTORIA
;    Entrada: AL = 1 (GAME OVER) o 2 (VICTORIA).
;    Muestra el resumen de la partida, actualiza el High Score si hay
;    record nuevo y pregunta que hacer.
;    Salida: AL = 1 (jugar otra partida) o AL = 0 (menu). Cambia AH.
; ---------------------------------------------------------------------
PANTALLA_FINAL PROC
    PUSH BX

    LIMPIAR_PANTALLA
    POSICIONAR 3, 0
    CMP  AL, 2
    JE   PF_VICTORIA

    SONIDO
    IMPRIMIR_COLOR MSG_GAMEOVER, C_MAL
    JMP  PF_RESUMEN

PF_VICTORIA:
    SONIDO
    SONIDO
    IMPRIMIR_COLOR MSG_VICTORIA, C_BIEN

PF_RESUMEN:
    IMPRIMIR_COLOR MSG_F_PUNTOS, C_INFO
    IMPRIMIR_NUM   PUNTOS, C_TEXTO
    IMPRIMIR_COLOR MSG_F_RONDAS, C_INFO
    IMPRIMIR_NUM   RONDA, C_TEXTO
    IMPRIMIR_COLOR MSG_F_GANADAS, C_INFO
    IMPRIMIR_NUM   GANADAS, C_BIEN
    IMPRIMIR_COLOR MSG_F_PERDIDAS, C_INFO
    IMPRIMIR_NUM   PERDIDAS, C_MAL
    IMPRIMIR_COLOR MSG_F_EMPATES, C_INFO
    IMPRIMIR_NUM   EMPATES, C_TITULO

    ; High Score: si el puntaje supera el record, se reemplaza
    MOV  AX, PUNTOS
    CMP  AX, HIGH_SCORE
    JBE  PF_SIN_RECORD
    MOV  HIGH_SCORE, AX
    IMPRIMIR_COLOR MSG_NUEVO_RECORD, C_TITULO
    JMP  PF_OPCIONES

PF_SIN_RECORD:
    IMPRIMIR_COLOR MSG_F_RECORD, C_INFO
    IMPRIMIR_NUM   HIGH_SCORE, C_TEXTO

PF_OPCIONES:
    IMPRIMIR_COLOR MSG_FINAL_OPC, C_TEXTO

PF_LEER:
    LEER_TECLA
    MAYUSCULA
    CMP  AL, 'R'
    JE   PF_REINICIAR
    CMP  AL, 'M'
    JE   PF_MENU
    JMP  PF_LEER                ; otra tecla: se ignora

PF_REINICIAR:
    MOV  AL, 1
    JMP  PF_FIN

PF_MENU:
    MOV  AL, 0

PF_FIN:
    POP  BX
    RET
PANTALLA_FINAL ENDP


; ---------------------------------------------------------------------
;  CALC_DI: calcula la direccion de una celda en la memoria de video
;    Entrada: DH = fila, DL = columna.  Salida: DI = desplazamiento.
;    Mapeo de memoria: en modo texto 80x25 cada celda ocupa 2 bytes
;    (caracter y atributo/color) a partir del segmento B800h, asi que
;    la celda (fila, columna) esta en (fila * 80 + columna) * 2.
;    Solo cambia DI.
; ---------------------------------------------------------------------
CALC_DI PROC
    PUSH AX
    MOV  AL, DH
    MOV  AH, COLUMNAS
    MUL  AH                     ; AX = fila * 80
    ADD  AL, DL
    ADC  AH, 0                  ; AX = fila * 80 + columna
    SHL  AX, 1                  ; * 2 bytes por celda
    MOV  DI, AX
    POP  AX
    RET
CALC_DI ENDP


; ---------------------------------------------------------------------
;  ESCRIBIR_VIDEO: escribe un caracter con color directo en la memoria
;    de video (segmento B800h), sin usar interrupciones.
;    Entrada: AL = caracter, BL = color, DH = fila, DL = columna.
;    No cambia ningun registro.
; ---------------------------------------------------------------------
ESCRIBIR_VIDEO PROC
    PUSH AX
    PUSH DI
    PUSH ES

    PUSH AX
    MOV  AX, VIDEO_SEG
    MOV  ES, AX                 ; ES apunta a la memoria de video
    POP  AX

    CALL CALC_DI                ; DI = celda (DH, DL)
    MOV  AH, BL                 ; AL = caracter, AH = color
    MOV  ES:[DI], AX            ; guarda los 2 bytes de la celda

    POP  ES
    POP  DI
    POP  AX
    RET
ESCRIBIR_VIDEO ENDP


; ---------------------------------------------------------------------
;  PUT_CHAR_COLOR: dibuja un caracter con color y avanza el cursor
;    Entrada: AL = caracter, BL = color (atributo).
;    Lee la posicion del cursor (INT 10h/03h), escribe el caracter en
;    la memoria de video y mueve el cursor una columna (INT 10h/02h).
;    No cambia ningun registro.
; ---------------------------------------------------------------------
PUT_CHAR_COLOR PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    PUSH AX
    PUSH BX
    MOV  AH, 03h                ; DH, DL = fila, columna del cursor
    MOV  BH, 0
    INT  10h
    POP  BX
    POP  AX

    CALL ESCRIBIR_VIDEO

    INC  DL                     ; una columna a la derecha
    MOV  AH, 02h
    MOV  BH, 0
    INT  10h

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
PUT_CHAR_COLOR ENDP


; ---------------------------------------------------------------------
;  PRINT_COLOR: muestra un texto terminado en '$' con un color
;    Entrada: DX = direccion del texto, BL = color.
;    Para que sea rapido, lee el cursor una sola vez y copia cada
;    caracter con su color directo a la memoria de video con STOSW
;    (guarda AX en ES:DI y suma 2 a DI). Al final deja el cursor
;    despues del texto. CR (0Dh) y LF (0Ah) se mandan con INT 21h/02h
;    para que hagan el salto de linea (y el scroll si hace falta).
;    El caracter '#' se dibuja como bloque solido (BLOQUE) para los
;    logos. No cambia ningun registro.
; ---------------------------------------------------------------------
PRINT_COLOR PROC
    PUSH AX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES

    MOV  SI, DX                 ; SI recorre el texto
    MOV  AX, VIDEO_SEG
    MOV  ES, AX                 ; ES:DI = memoria de video
    CLD                         ; STOSW avanza hacia adelante
    MOV  AH, BL                 ; AH = color de todo el texto
    CALL LEER_CURSOR            ; DH, DL = fila, columna
    CALL CALC_DI

PC_SIGUIENTE:
    MOV  AL, [SI]
    INC  SI
    CMP  AL, '$'                ; fin del texto
    JE   PC_FIN
    CMP  AL, 0Dh
    JE   PC_CONTROL
    CMP  AL, 0Ah
    JE   PC_CONTROL
    CMP  AL, '#'
    JNE  PC_DIBUJAR
    MOV  AL, BLOQUE             ; '#' -> bloque solido
PC_DIBUJAR:
    STOSW                       ; ES:[DI] = AL (caracter), AH (color)
    INC  DL                     ; siguiente columna
    JMP  PC_SIGUIENTE

PC_CONTROL:
    CALL MOVER_CURSOR           ; el cursor real va a (DH, DL)
    PUSH AX
    MOV  DL, AL                 ; INT 21h/02h: mostrar CR o LF
    MOV  AH, 02h
    INT  21h
    POP  AX
    CALL LEER_CURSOR            ; nueva fila / columna
    CALL CALC_DI
    JMP  PC_SIGUIENTE

PC_FIN:
    CALL MOVER_CURSOR           ; deja el cursor despues del texto
    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  AX
    RET
PRINT_COLOR ENDP


; ---------------------------------------------------------------------
;  LEER_CURSOR: Salida DH = fila, DL = columna del cursor (INT 10h/03h).
;    Solo cambia DX.
; ---------------------------------------------------------------------
LEER_CURSOR PROC
    PUSH AX
    PUSH BX
    PUSH CX
    MOV  AH, 03h
    MOV  BH, 0
    INT  10h
    POP  CX
    POP  BX
    POP  AX
    RET
LEER_CURSOR ENDP


; ---------------------------------------------------------------------
;  MOVER_CURSOR: pone el cursor en DH = fila, DL = columna
;    (INT 10h/02h). No cambia ningun registro.
; ---------------------------------------------------------------------
MOVER_CURSOR PROC
    PUSH AX
    PUSH BX
    MOV  AH, 02h
    MOV  BH, 0
    INT  10h
    POP  BX
    POP  AX
    RET
MOVER_CURSOR ENDP


; ---------------------------------------------------------------------
;  PRINT_NUM: muestra un numero sin signo de 16 bits en decimal
;    Entrada: AX = numero (0 a 65535), BL = color.
;    Divide entre 10 varias veces; cada residuo es un digito (de
;    derecha a izquierda), por eso se guardan en la pila y se sacan
;    al reves para mostrarlos en orden. No cambia ningun registro.
; ---------------------------------------------------------------------
PRINT_NUM PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  SI, 10                 ; divisor
    MOV  CX, 0                  ; CX = cantidad de digitos

PN_DIVIDIR:
    MOV  DX, 0                  ; DX:AX / 10 -> AX = cociente, DX = residuo
    DIV  SI
    PUSH DX                     ; guarda el digito
    INC  CX
    CMP  AX, 0
    JNE  PN_DIVIDIR

PN_MOSTRAR:
    POP  AX                     ; saca los digitos del mas significativo
    ADD  AL, '0'                ; numero -> caracter
    CALL PUT_CHAR_COLOR
    LOOP PN_MOSTRAR

    POP  SI
    POP  DX
    POP  CX
    POP  AX
    RET
PRINT_NUM ENDP


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

END MAIN

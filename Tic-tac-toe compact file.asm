.MODEL SMALL
.STACK 100H

.DATA

    ; ----------------------------------------------------------
      ; Index layout:
    ;   0 | 1 | 2
    ;   3 | 4 | 5
    ;   6 | 7 | 8
    ; Values: 0 = Empty, 1 = Player (X), 2 = Computer (O)
    ; ----------------------------------------------------------
    BOARD           DB  9 DUP(0)

   
    CURRENT_TURN    DB  1     ; 1 = Player turn, 2 = Computer turn

    
    GAME_STATE      DB  0          ; 0=ongoing, 1=Player wins, 2=Computer wins, 3=Draw

    ; Score counters 
    PLAYER_SCORE    DB  0
    COMP_SCORE      DB  0

    ; 8 winning lines 
    WIN_TABLE       DB  0,1,2
                    DB  3,4,5
                    DB  6,7,8
                    DB  0,3,6
                    DB  1,4,7
                    DB  2,5,8
                    DB  0,4,8
                    DB  2,4,6

     ; Feature 3 & 4 strings
     
    MSG_INVALID     DB  'Invalid! Try again (1-9, empty cell): $'
    MSG_PLAYER_WIN  DB  'YOU WIN! Congratulations!$'
    MSG_COMP_WIN    DB  'COMPUTER WINS!$'
    MSG_DRAW        DB  'DRAW! Well played.$'
    MSG_NEWLINE     DB  0Dh, 0Ah, '$'

    MSG_BAR         DB  ' | $'
    MSG_DASH        DB  '---------',0Dh,0Ah,'$'

     ;  Feature 5,6 string
       
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

    MSG_WHO_FIRST   DB  0Dh,0Ah,'  Who goes first?  P = Player   C = Computer',0Dh,0Ah,'  Your choice: $'

    MSG_INVALID_KEY2 DB  0Dh,0Ah, '  Invalid! Press P or C only.',0Dh,0Ah,'$'


.CODE

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX


OUTER_REPLAY_GAME_LOOP:

    CALL RESET_GAME
    CALL ASK_WHO_FIRST


GAME_LOOP:
    ; checks first if game ended alr
    MOV  AL, GAME_STATE
    CMP  AL, 0
    JNE  SHOW_RESULT   

     
    ; to know whose turn
    MOV  AL, CURRENT_TURN
    CMP  AL, 1
    JE   DO_PLAYER_TURN
    JMP  DO_COMPUTER_TURN

; ================================================================
; [Pushpita] Feature 3: SINGLE PLAYER MODE
; ================================================================

DO_PLAYER_TURN:

        MOV  AL, 0                                      ; 0 = player turn
    CALL SHOW_TURN_INDICATOR
  
       
    ; reads one key for board idx
    MOV  AH, 01h
    INT  21h              

    ; ascii 1-9 to board index 0-8
    MOV  BL, AL
    SUB  BL, '1'                  
    MOV  BH, 0                 

    ; out of range
     CMP  BL, 0
    JL   INVALID_MOVE
    CMP  BL, 8
    JG   INVALID_MOVE

    ; empty cell check
    MOV  BH, 0                         
    MOV  AL, BOARD[BX]
    CMP  AL, 0
    JNE  INVALID_MOVE

    ; player 1 = X
    MOV  BH, 0
    MOV  BOARD[BX], 1
    CALL PRINT_NEWLINE
    CALL DRAW_BOARD
    CALL CHECK_WIN_DRAW

    MOV  CURRENT_TURN, 2    ; switch to computer
    JMP  GAME_LOOP

INVALID_MOVE:
    CALL PRINT_NEWLINE
    LEA  DX, MSG_INVALID
    CALL PRINT_STRING
    CALL PRINT_NEWLINE
    JMP  GAME_LOOP


DO_COMPUTER_TURN:

      MOV  AL, 1                           ; 1 = computer turn
    CALL SHOW_TURN_INDICATOR
 
     CALL COMPUTER_MOVE

 CALL DRAW_BOARD
   
    ; check win/draw after computer move
    CALL CHECK_WIN_DRAW

    MOV  CURRENT_TURN, 1    ; switch back to player
    JMP  GAME_LOOP


SHOW_RESULT:
    CALL PRINT_NEWLINE
    MOV  AL, GAME_STATE

    CMP  AL, 1
    JE   PLAYER_WINS
    CMP  AL, 2
    JE   COMP_WINS

    LEA  DX, MSG_DRAW
    CALL PRINT_STRING
    CALL PRINT_NEWLINE
    JMP  DO_REPLAY_MENU

PLAYER_WINS:
    INC  PLAYER_SCORE
    LEA  DX, MSG_PLAYER_WIN
    CALL PRINT_STRING
    CALL PRINT_NEWLINE
    JMP  DO_REPLAY_MENU

COMP_WINS:
    INC  COMP_SCORE
    LEA  DX, MSG_COMP_WIN
    CALL PRINT_STRING
    CALL PRINT_NEWLINE


DO_REPLAY_MENU:
    CALL SHOW_REPLAY_MENU   ; if AX=1 then replay or AX=0 then quit

    CMP  AX, 1
    JE   OUTER_REPLAY_GAME_LOOP         


MOV  AX, 4C00H
INT  21H

MAIN ENDP



; ================================================================
; [Pushpita] Feature 4: CHECK_WIN_DRAW
; Sets GAME_STATE: 1=Player wins, 2=Computer wins, 3=Draw
; ================================================================

CHECK_WIN_DRAW PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  SI, 0
    MOV  CX, 8                     ; 8 lines

WIN_LOOP:
    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI]
    MOV  AL, BOARD[BX]                    ; value at A

    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI+1]
    MOV  AH, BOARD[BX]                     ; value at B

   ; A == B?
    CMP  AL, AH
    JNE  NEXT_LINE
   
    MOV  BH, 0
    MOV  BL, WIN_TABLE[SI+2]
    MOV  DL, BOARD[BX]                  ; value at C
 
   ; A == C?
    CMP  AL, DL
    JNE  NEXT_LINE

   ; Not empty (0)?
    CMP  AL, 0
    JE   NEXT_LINE

  
   ; Winner found - AL = 1 or 2
    MOV  GAME_STATE, AL
    JMP  WIN_DONE

NEXT_LINE:
    ADD  SI, 3
    LOOP WIN_LOOP

    ; Check draw - board full?
    MOV  CX, 9
    MOV  SI, 0

DRAW_LOOP:
    MOV  BH, 0
    MOV  BX, SI
    MOV  AL, BOARD[BX]
    CMP  AL, 0
    JE   WIN_DONE           ; found empty cell, not a draw
    INC  SI
    LOOP DRAW_LOOP

    MOV  GAME_STATE, 3      ; all cells full = draw

WIN_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CHECK_WIN_DRAW ENDP



; ================================================================
; [Subah] Feature 1: DRAW_BOARD goes here
; ================================================================
DRAW_BOARD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    CALL PRINT_NEWLINE

    MOV CX, 9
    MOV BX, 0

DRAW_CELL:
    MOV AL, BOARD[BX]

    CMP AL, 0
    JE PRINT_NUMBER
    CMP AL, 1
    JE PRINT_X

PRINT_O:
    MOV DL, 'O'
    JMP PRINT_CHAR

PRINT_X:
    MOV DL, 'X'
    JMP PRINT_CHAR

PRINT_NUMBER:
    MOV DL, BL
    ADD DL, '1'

PRINT_CHAR:
    MOV AH, 02h
    INT 21h

    CMP BL, 2
    JE ROW_END
    CMP BL, 5
    JE ROW_END
    CMP BL, 8
    JE BOARD_DONE_ROW

    LEA DX, MSG_BAR
    CALL PRINT_STRING
    JMP NEXT_CELL

ROW_END:
    CALL PRINT_NEWLINE
    LEA DX, MSG_DASH
    CALL PRINT_STRING
    JMP NEXT_CELL

BOARD_DONE_ROW:
    CALL PRINT_NEWLINE

NEXT_CELL:
    INC BX
    LOOP DRAW_CELL

    POP DX
    POP CX
    POP BX
    POP AX
    RET
DRAW_BOARD ENDP


; ================================================================
; [Subah] Feature 2: COMPUTER_MOVE goes here
; ================================================================
COMPUTER_MOVE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    ; 1) First try to win if computer has 2 in a line
    MOV SI, 0
    MOV CX, 8

WIN_SCAN_LOOP:
    CALL TRY_WIN_LINE
    CMP AL, 1
    JE COMPUTER_DONE

    ADD SI, 3
    LOOP WIN_SCAN_LOOP

    ; 2) If no winning move, block player
    MOV SI, 0
    MOV CX, 8

BLOCK_LOOP:
    CALL TRY_BLOCK_LINE
    CMP AL, 1
    JE COMPUTER_DONE

    ADD SI, 3
    LOOP BLOCK_LOOP

    ; 3) Otherwise pick first empty cell
    MOV CX, 9
    MOV BX, 0

RANDOM_SCAN:
    MOV BH, 0
    MOV AL, BOARD[BX]
    CMP AL, 0
    JE RANDOM_PLACE
    INC BX
    LOOP RANDOM_SCAN
    JMP COMPUTER_DONE

RANDOM_PLACE:
    MOV BOARD[BX], 2

COMPUTER_DONE:
    POP SI
    POP CX
    POP BX
    POP AX
    RET
COMPUTER_MOVE ENDP

TRY_WIN_LINE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV AL, 0

    MOV BL, WIN_TABLE[SI]
    MOV BH, 0
    MOV CL, BOARD[BX]

    MOV BL, WIN_TABLE[SI+1]
    MOV BH, 0
    MOV CH, BOARD[BX]

    MOV BL, WIN_TABLE[SI+2]
    MOV BH, 0
    MOV DL, BOARD[BX]

    ; Case: computer at first two, third empty
    CMP CL, 2
    JNE WIN_CASE2
    CMP CH, 2
    JNE WIN_CASE2
    CMP DL, 0
    JNE WIN_CASE2

    MOV BL, WIN_TABLE[SI+2]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1
    JMP WIN_LINE_DONE

WIN_CASE2:
    ; Case: computer at first and third, second empty
    CMP CL, 2
    JNE WIN_CASE3
    CMP DL, 2
    JNE WIN_CASE3
    CMP CH, 0
    JNE WIN_CASE3

    MOV BL, WIN_TABLE[SI+1]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1
    JMP WIN_LINE_DONE

WIN_CASE3:
    ; Case: computer at second and third, first empty
    CMP CH, 2
    JNE WIN_LINE_DONE
    CMP DL, 2
    JNE WIN_LINE_DONE
    CMP CL, 0
    JNE WIN_LINE_DONE

    MOV BL, WIN_TABLE[SI]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1

WIN_LINE_DONE:
    POP SI
    POP DX
    POP CX
    POP BX
    RET
TRY_WIN_LINE ENDP

TRY_BLOCK_LINE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV AL, 0

    MOV BL, WIN_TABLE[SI]
    MOV BH, 0
    MOV CL, BOARD[BX]

    MOV BL, WIN_TABLE[SI+1]
    MOV BH, 0
    MOV CH, BOARD[BX]

    MOV BL, WIN_TABLE[SI+2]
    MOV BH, 0
    MOV DL, BOARD[BX]

    ; Case: player at first two, third empty
    CMP CL, 1
    JNE CHECK_CASE2
    CMP CH, 1
    JNE CHECK_CASE2
    CMP DL, 0
    JNE CHECK_CASE2

    MOV BL, WIN_TABLE[SI+2]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1
    JMP BLOCK_DONE

CHECK_CASE2:
    ; Case: player at first and third, second empty
    CMP CL, 1
    JNE CHECK_CASE3
    CMP DL, 1
    JNE CHECK_CASE3
    CMP CH, 0
    JNE CHECK_CASE3

    MOV BL, WIN_TABLE[SI+1]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1
    JMP BLOCK_DONE

CHECK_CASE3:
    ; Case: player at second and third, first empty
    CMP CH, 1
    JNE BLOCK_DONE
    CMP DL, 1
    JNE BLOCK_DONE
    CMP CL, 0
    JNE BLOCK_DONE

    MOV BL, WIN_TABLE[SI]
    MOV BH, 0
    MOV BOARD[BX], 2
    MOV AL, 1

BLOCK_DONE:
    POP SI
    POP DX
    POP CX
    POP BX
    RET
TRY_BLOCK_LINE ENDP

; ================================================================
; [Shaira] Feature 5: SHOW_TURN_INDICATOR
; ================================================================

SHOW_TURN_INDICATOR PROC

    PUSH AX                 ; turn value
    PUSH DX                 

    CMP  AL, 0
    JE   PRINT_PLAYER_TURN

     LEA  DX, MSG_COMP_TURN
    CALL PRINT_STRING
    JMP  TURN_DONE

PRINT_PLAYER_TURN:
    LEA  DX, MSG_YOUR_TURN
    CALL PRINT_STRING

TURN_DONE:
    POP  DX                
    POP  AX                 

    RET
SHOW_TURN_INDICATOR ENDP


; ================================================================
; [Shaira] Feature 6: SHOW_REPLAY_MENU
; ================================================================

SHOW_REPLAY_MENU PROC

    PUSH DX                

   
    MOV  AL, GAME_STATE
    MOV  AH, 0
    PUSH AX                 ; game state saved 

    
    LEA  DX, MSG_GAME_OVER   ; prints game over
    CALL PRINT_STRING

    
    LEA  DX, MSG_SCORE_HDR ; prints scores
    CALL PRINT_STRING

    LEA  DX, MSG_PSCORE
    CALL PRINT_STRING
    MOV  AL, PLAYER_SCORE
    ADD  AL, 30H
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h
    CALL PRINT_NEWLINE

    LEA  DX, MSG_CSCORE
    CALL PRINT_STRING
    MOV  AL, COMP_SCORE
    ADD  AL, 30H           
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h
    CALL PRINT_NEWLINE

REPLAY_ASK:
    LEA  DX, MSG_REPLAY_ASK
    CALL PRINT_STRING

    MOV  AH, 08h
    INT  21h
    
    ; accepts both lowercase and uppercase
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

    ; any other key 
    LEA  DX, MSG_INVALID_KEY
    CALL PRINT_STRING
    JMP  REPLAY_ASK

WANTS_REPLAY:
    LEA  DX, MSG_REPLAYING
    CALL PRINT_STRING

    POP  AX                 
    POP  DX                

    MOV  AX, 1              ; 1 = replay
    RET

WANTS_QUIT:
    LEA  DX, MSG_GOODBYE
    CALL PRINT_STRING

    POP  AX                 ;saved game state 
    POP  DX                

    MOV  AX, 0              ;: 0 = quit
    RET

SHOW_REPLAY_MENU ENDP

; ================================================================
; [Shaira] Feature 6: RESET_GAME when replay
; ================================================================

RESET_GAME PROC
    PUSH AX
    PUSH BX
    PUSH CX

    MOV  GAME_STATE,    0
    MOV  CURRENT_TURN,  1

    ; clears all 9 cells 
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

; -----------------------------------------------
; Ask player to choose who moves first.
; P = Player (CURRENT_TURN = 1)
; C = Computer (CURRENT_TURN = 2)
; -----------------------------------------------
ASK_WHO_FIRST PROC
    PUSH AX
    PUSH DX

ASK_FIRST_LOOP:
    LEA  DX, MSG_WHO_FIRST
    CALL PRINT_STRING

    MOV  AH, 08h
    INT  21h                

    
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
    MOV  CURRENT_TURN, 1
    JMP  FIRST_DONE

CHECK_C:
    CMP  AL, 'C'
    JNE  INVALID_FIRST
    MOV  CURRENT_TURN, 2
    JMP  FIRST_DONE

INVALID_FIRST:
    LEA  DX, MSG_INVALID_KEY2
    CALL PRINT_STRING
    JMP  ASK_FIRST_LOOP

FIRST_DONE:
    CALL PRINT_NEWLINE
    POP  DX
    POP  AX
    RET
ASK_WHO_FIRST ENDP

; -----------------------------------------------
;  UTILITY: PRINT_STRING
; -----------------------------------------------
PRINT_STRING PROC
    MOV  AH, 09h
    INT  21h
    RET
PRINT_STRING ENDP

; -----------------------------------------------
;  UTILITY: PRINT_NEWLINE
; -----------------------------------------------
PRINT_NEWLINE PROC
    LEA  DX, MSG_NEWLINE
    MOV  AH, 09h
    INT  21h
    RET
PRINT_NEWLINE ENDP

END 

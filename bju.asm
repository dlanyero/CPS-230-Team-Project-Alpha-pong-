bits 16
org 0x100

SECTION .text
main:
    mov     ax, 0xB800
    mov     es, ax                  ; moving directly into a segment register is not allowed
    mov     bx, 996                 ; offset for approximately the middle of the screen

    mov     ah, 0x0
    mov     al, 0x1
    int     0x10                    ; set video to text mode

    call print_score
    call print_players
    call print_ball

    mov     ah, 0x0                 ; wait for user input
    int     0x16

    mov     ah, 0x4c                ; exit
    mov     al, 0
    int     0x21

global print_score
print_score:
    mov     bx, 60                  ; you can assume that es has not been tampered with.
                                    ; also assume that the video text mode has been set.
    mov     word [es:bx+0], 0x0753  ; SCORE: --> {0x53, 0x43, 0x4f, 0x52, 0x45, 0x7c, space}
    mov     word [es:bx+2], 0x0743  ; no blink. black background, non-bright white font.
    mov     word [es:bx+4], 0x074f
    mov     word [es:bx+6], 0x0752
    mov     word [es:bx+8], 0x0745
    mov     word [es:bx+10], 0x077c

    mov     cx, 0x0730              ; the '0' character
    add     cx, [score]
    mov     word [es: bx + 14], cx
    ret

global print_players
print_players:
    mov     ax, 80                  ; multiplying to find the correct location to put the value.
    mov     dx, word [player_paddle_loc]
    imul    ax, dx
    mov     bx, ax

    mov     word [es:bx], 0x07db          ; 0xa6 --> block
    mov     word [es:bx+80], 0x07db
    mov     word [es:bx+160], 0x07db

    mov     ax, 80                  ; multiplying to find the correct location to put the value.
    mov     dx, word [comput_paddle_loc]
    imul    ax, dx
    mov     bx, ax

    mov     word [es:bx+78], 0x07db          ; 0xdb --> block
    mov     word [es:bx+158], 0x07db
    mov     word [es:bx+238], 0x07db

    ret

global print_ball
print_ball:
    mov     ax, 80                  ; multiplying to find the correct location to put the value.
    mov     dx, word [ball_y]
    imul    ax, dx
    mov     bx, ax                  ; y

    add     bx, [ball_x]            ; x
    mov     word [es: bx], 0x07db   ; print (x, y)
    ret



SECTION .data
    player_paddle_loc: dw 12    ; [0, 22]
    score: dw 2                 ; start score at 2 [0, 9]
    ball_x: dw 40               ; [0, 78]
    ball_y: dw 8                ; [0, 23]
    ball_dx: dw 1               ; {-2, -1, 0, 1, 2}
    ball_dy: dw 1               ; {-4, -2, 0, 2, 4}
    comput_paddle_loc: dw 15    ; [0, 22]

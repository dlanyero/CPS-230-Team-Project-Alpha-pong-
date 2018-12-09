bits 16

org 0x100

SECTION .text
main:
	mov ax, cs
	mov ds, ax
    mov     byte [task_status], 1               ; set main task to active

	mov     ah, 0x0
    mov     al, 0x1
    int     0x10                    ; set video to text mode
	
    lea     di, [task_a]                        ; create task a
    call    spawn_new_task

    lea     di, [task_b]                        ; create task b
    call    spawn_new_task
	
	lea     di, [task_c]
	call 	spawn_new_task

    ; a completely useless something
.loop_forever_main:                             ; have main print for eternity
    mov     dx, 25
    call    yield                               ; we are done printing, let another task know they can print
    jmp     .loop_forever_main
    ; does not terminate or return

; di should contain the address of the function to run for a task
spawn_new_task:
    lea     bx, [stack_pointers]                ; get the location of the stack pointers
    add     bx, [current_task]                  ; get the location of the current stack pointer
    mov     [bx], sp                            ; save current stack so we can switch back
    mov     cx, [current_task]                  ; look for a new task
    add     cx, 2                               ; start searching at the next one though
.sp_loop_for_available_stack:
    cmp     cx, [current_task]                  ; we are done when we get back to the original
    jne     .sp_check_if_available
    jmp     .sp_no_available_stack
.sp_check_if_available:
    lea     bx, [task_status]                   ; get status of this stack
    add     bx, cx
    cmp     word [bx], 0
    je      .sp_is_available
    add     cx, 2                               ; next stack to search
    and     cx, 0x0F                            ; make sure stack to search is always less than 64
    jmp     .sp_loop_for_available_stack
.sp_is_available:
    lea     bx, [task_status]                   ; we found a stack, set it to active
    add     bx, cx
    mov     word [bx], 1
    lea     bx, [stack_pointers]                ; switch to the fake stack so we can do stuff with it
    add     bx, cx
    mov     sp, [bx]                            ; swap stacks
    push    di                                  ; push address of function to run
    pusha                                       ; push registers
    pushf                                       ; push flags
    lea     bx, [stack_pointers]                ; update top of this stack
    add     bx, cx
    mov     [bx], sp
.sp_no_available_stack:                         ; restore to original stack
    lea     bx, [stack_pointers]
    add     bx, [current_task]
    mov     sp, [bx]
    ret

yield:
    pusha                                       ; push registers
    pushf                                       ; push flags
    lea     bx, [stack_pointers]                ; save current stack pointer
    add     bx, [current_task]
    mov     [bx], sp
    mov     cx, [current_task]                  ; look for a new task
    add     cx, 2                               ; start searching at the next one though
.y_check_if_enabled:
    lea     bx, [task_status]
    add     bx, cx
    cmp     word [bx], 1
    je      .y_task_available
    add     cx, 2                               ; next stack to search
    and     cx, 0x0F                            ; make sure stack to search is always less than 64
    jmp     .y_check_if_enabled
.y_task_available:
    mov     bx, cx
    mov     [current_task], bx
    mov     bx, stack_pointers                  ; update stack pointer
    add     bx, [current_task]
    mov     sp, [bx]
    popf
    popa
    ret

task_a:
.loop_forever_1:
    call    update_game
    call    yield
    jmp     .loop_forever_1
    ; does not terminate or return

task_b:
.loop_forever_2:
    call    print_screen
	;call    Play_Sound
    call    yield
    jmp     .loop_forever_2
    ; does not terminate or return
task_c:
.loop_forever_3:
	call  Play_Sound
	call  yield
	jmp  .loop_forever_3

; takes a char to print in dx
; no return value
putchar:
    mov     ax, dx          ; call interrupt x10 sub interrupt xE
    mov     ah, 0x0E
    mov     cx, 1
    int     0x10
    ret

;takes an address to write to in di
;writes to address until a newline is encountered
;returns nothing
putstring:
    cmp     byte [di], 0        ; see if the current byte is a null terminator
    je      .done               ; nope keep printing
.continue:
    mov     dl, [di]            ; grab the next character of the string
    mov     dh, 0               ; print it
    call    putchar
    inc     di                  ; move to the next character
    jmp     putstring
.done:
    ret

; Easy function: printing the board.
; run through all the variables and print them out.
; how hard could that be?
; I just need to update the screen memory, since there is already a thread which
; prints out the screen. Our screen is 80x25.
print_screen:
    ; first I print the score in the top corner.
    mov     ax, 0xB800
    mov     es, ax                  ; moving directly into a segment register is not allowed
    mov     bx, 80                 ; offset for approximately the middle of the screen

    call    print_score
    call    print_players
    call    print_ball
	call paint_screen_black
	
	cmp word[ball_x], 0
	je reset1
	dec word[ball_x]
	cmp word[ball_y], 0
	je reset2
	dec word[ball_y]
	
reset1:
	mov word[ball_x] , 80
reset2:
	mov word[ball_y], 16

global paint_screen_black
paint_screen_black:
	
		xor     bx, bx
	    jmp .clearing_screen
.clearing_screen:
    cmp bx, 4000 ; or however pixels you have * 2
    jge .end_while
    mov word [es:bx], 0
    add bx, 2
    jmp .clearing_screen
.end_while:

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

	;dec bx
	;cmp bx, 0
	;je .reset_value_y
	
	
    add     bx, [ball_x]            ; x
	;dec bx
	;cmp bx, 0 
	;je .reset_value_x
    mov     word [es: bx], 0x07db   ; print (x, y)
	;dec ball_dx
    ret
.reset_value_x:
	mov bx, ball_x
	
.reset_value_y:
	mov bx, ball_y

; need a function to move the ball one place.
; if the ball hits a wall, then check what wall it is.
; if it's the wall on the back side, then end the game.
; if it's a top or bottom wall, then just change the y direction.
; if it hits a paddle, change the x or y appriately.
; . . . this is the hard function.
; just update the paddles for now.
; somewhat addapted from https://stackoverflow.com/questions/13143774/how-to-read-key-without-waiting-for-it-assembly-8086
global update_game
update_game:
    mov ah, 01h                     ; checks if a key is pressed
    int 16h
    jnz process_key                 ; 0 == not-pressed
    ret

    mov ah, 00h                     ; get the keystroke
    int 16h

process_key:
    mov ah, 00h                     ; get the keystroke
    int 16h

    cmp     al, 119              ; w
    jne     w_not_pressed
    mov     dx, [comput_paddle_loc]
    sub     dx, 1
    mov     [comput_paddle_loc], dx
    jmp     end_update
w_not_pressed:
    cmp     al, 115              ; s
    jne     s_not_pressed
    mov     dx, [comput_paddle_loc] ;So this is how you adjust stuff. You temprarily move it into a register and increament the register and them move it back to where is it supposed to be. 
    add     dx, 1
    mov     [comput_paddle_loc], dx
    jmp     end_update
s_not_pressed:
    cmp     al, 113              ; q
    jne     q_not_pressed
    mov     dx, [player_paddle_loc]
    sub     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
q_not_pressed:
    cmp     al, 97              ; a
    jne     a_not_pressed
    mov     dx, [player_paddle_loc]
    add     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
a_not_pressed:

end_update:
    ret                     ; at the very least.

global Play_Sound
Play_Sound:
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
	jmp .play_D
	;jmp .pause1
	;jmp .pause2
	jmp .play_G
	;jmp .pause1
	;jmp .pause2
	jmp .play_A
	;jmp .pause1
	;jmp .pause2
	jmp .play_B
	;jmp .pause1
	;jmp .pause2
		
.play_B:
	mov     al, 182         ; Prepare the speaker for the
        out     43h, al         ;  note.
        mov     ax, 2415        ; Frequency number (in decimal)
                                ;  for middle C.
        out     42h, al         ; Output low byte.
        mov     al, ah          ; Output high byte.
        out     42h, al 
        in      al, 61h         ; Turn on note (get value from
                                ;  port 61h).
        or      al, 00000011b   ; Set bits 1 and 0.
        out     61h, al         ; Send new value.
        mov     bx, 25 
.pause1:
        mov     cx, 65535
.pause2:
        dec     cx
        jne     .pause2
        dec     bx
        jne     .pause1
        in      al, 61h         ; Turn off note (get value from
                                ;  port 61h).
        and     al, 11111100b   ; Reset bits 1 and 0.
        out     61h, al         ; Send new value.

.play_D:
	mov     al, 182         ; Prepare the speaker for the
        out     43h, al         ;  note.
        mov     ax, 2031       ; Frequency number (in decimal)
                                ;  for middle C.
        out     42h, al         ; Output low byte.
        mov     al, ah          ; Output high byte.
        out     42h, al 
        in      al, 61h         ; Turn on note (get value from
                                ;  port 61h).
        or      al, 00000011b   ; Set bits 1 and 0.
        out     61h, al         ; Send new value.
        mov     bx, 25 

.play_G:
		mov     al, 182         ; Prepare the speaker for the
        out     43h, al         ;  note.
        mov     ax, 3043       ; Frequency number (in decimal)
                                ;  for middle C.
        out     42h, al         ; Output low byte.
        mov     al, ah          ; Output high byte.
        out     42h, al 
        in      al, 61h         ; Turn on note (get value from
                                ;  port 61h).
        or      al, 00000011b   ; Set bits 1 and 0.
        out     61h, al         ; Send new value.
        mov     bx, 25 

	

.play_A:
		mov     al, 182         ; Prepare the speaker for the
        out     43h, al         ;  note.
        mov     ax, 5423       ; Frequency number (in decimal)
                                ;  for middle C.
        out     42h, al         ; Output low byte.
        mov     al, ah          ; Output high byte.
        out     42h, al 
        in      al, 61h         ; Turn on note (get value from
                                ;  port 61h).
        or      al, 00000011b   ; Set bits 1 and 0.
        out     61h, al         ; Send new value.
        mov     bx, 25 



SECTION .data
    player_paddle_loc: dw 12    ; [0, 22]
    score: dw 5                 ; start score at 2 [0, 9]
    ball_x: dw 40               ; even element of [0, 78]
    ball_y: dw 8                ; [0, 23]
    ball_dx: dw 1               ; {-2, -1, 0, 1, 2}
    ball_dy: dw 1               ; {-4, -2, 0, 2, 4}
    comput_paddle_loc: dw 15    ; [0, 22]

    task_main_str: db "I am task MAIN", 13, 10, 0

    current_task: dw 0          ; must always be a multiple of 2
    stacks: times (256 * 8) db 0 ; 31 fake stacks of size 256 bytes
    task_status: times 8 dw 0  ; 0 means inactive, 1 means active
    stack_pointers: dw 0        ; the first pointer needs to be to the real stack !
                    dw stacks + (256 * 1)
                    dw stacks + (256 * 2)
                    dw stacks + (256 * 3)
                    dw stacks + (256 * 4)
                    dw stacks + (256 * 5)
                    dw stacks + (256 * 6)
                    dw stacks + (256 * 7)
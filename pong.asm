bits 16

org 0x100

SECTION .text
main:
    mov     byte [task_status], 1               ; set main task to active

    lea     di, [task_a]                        ; create task a
    call    spawn_new_task

    lea     di, [task_b]                        ; create task b
    call    spawn_new_task

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
    and     cx, 0x2F                            ; make sure stack to search is always less than 64
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
    and     cx, 0x2F                            ; make sure stack to search is always less than 64
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
    call    yield
    jmp     .loop_forever_2
    ; does not terminate or return

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

    mov     ah, 0x0
    mov     al, 0x1
    int     0x10                    ; set video to text mode

    call    print_score
    call    print_players
    call    print_ball
    ret

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
    cmp     al, 87              ; w
    jne     w_not_pressed
    mov     dx, [player_paddle_loc]
    sub     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
w_not_pressed:
    cmp al, 83                  ; s
    jne s_not_pressed
    mov     dx, [player_paddle_loc]
    add     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
s_not_pressed:
    cmp     al, 81              ; q
    jne     q_not_pressed
    mov     dx, [comput_paddle_loc]
    sub     dx, 1
    mov     [comput_paddle_loc], dx
    jmp     end_update
q_not_pressed:
    cmp     al, 65              ; a
    jne     a_not_pressed
    mov     dx, [player_paddle_loc]
    sub     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
a_not_pressed:

end_update:
    ret                     ; at the very least.

SECTION .data
    player_paddle_loc: dw 12    ; [0, 22]
    score: dw 5                 ; start score at 2 [0, 9]
    ball_x: dw 40               ; even element of [0, 78]
    ball_y: dw 8                ; [0, 23]
    ball_dx: dw 1               ; {-2, -1, 0, 1, 2}
    ball_dy: dw 1               ; {-4, -2, 0, 2, 4}
    comput_paddle_loc: dw 15    ; [0, 22]


    current_task: dw 0          ; must always be a multiple of 2
    stacks: times (256 * 31) db 0 ; 31 fake stacks of size 256 bytes
    task_status: times 32 dw 0  ; 0 means inactive, 1 means active
    stack_pointers: dw 0        ; the first pointer needs to be to the real stack !
                    dw stacks + (256 * 1)
                    dw stacks + (256 * 2)
                    dw stacks + (256 * 3)
                    dw stacks + (256 * 4)
                    dw stacks + (256 * 5)
                    dw stacks + (256 * 6)
                    dw stacks + (256 * 7)
                    dw stacks + (256 * 8)
                    dw stacks + (256 * 9)
                    dw stacks + (256 * 10)
                    dw stacks + (256 * 11)
                    dw stacks + (256 * 12)
                    dw stacks + (256 * 13)
                    dw stacks + (256 * 14)
                    dw stacks + (256 * 15)
                    dw stacks + (256 * 16)
                    dw stacks + (256 * 17)
                    dw stacks + (256 * 18)
                    dw stacks + (256 * 19)
                    dw stacks + (256 * 20)
                    dw stacks + (256 * 21)
                    dw stacks + (256 * 22)
                    dw stacks + (256 * 23)
                    dw stacks + (256 * 24)
                    dw stacks + (256 * 25)
                    dw stacks + (256 * 26)
                    dw stacks + (256 * 27)
                    dw stacks + (256 * 28)
                    dw stacks + (256 * 29)
                    dw stacks + (256 * 30)
                    dw stacks + (256 * 31)

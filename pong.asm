bits 16
org 0x100
SECTION .text
main:
    mov ax, cs
    mov ds, ax
    mov     byte [task_status], 1               ; set main task to active
    mov     ah, 0x0
    mov     al, 0x1
    int     0x10                                ; set video to text mode

    lea     di, [task_a]
    call    spawn_new_task

    lea     di, [task_b]
    call    spawn_new_task

    lea     di, [task_c]
    call    spawn_new_task

    lea     di, [task_score_keeper]
    call    spawn_new_task

    lea     di, [task_run_ai]
    call    spawn_new_task

    lea     di, [task_paddle_collisions]
    call    spawn_new_task
    ; a completely useless something
.loop_forever_main:                             ; have main print for eternity
    mov     dx, 25
    call    yield                               ; we are done printing, let another task know they can print
    jmp     .loop_forever_main
    ; does not terminate or return

; spawns a new task (duh)
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

; To be called within a task to let another task take over.
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

; updates the paddle position when the key is hit.
task_a:
.loop_forever_1:
    call    update_game
    call    yield
    jmp     .loop_forever_1

; printing the screen
task_b:
.loop_forever_2:
    call    print_screen
    ;call    Play_Sound
    call    yield
    jmp     .loop_forever_2

; plays the music
task_c:
.loop_forever_3:
    call  Play_Sound
    call  yield
    jmp  .loop_forever_3

; updates the score when someone gets a point.
; restarts the game (zeros the scores) when someone wins
task_score_keeper:
.loop_forever_4:
    call    keep_score
    call    yield
    jmp     .loop_forever_4

; runs the ai
task_run_ai:
.loop_forever_5:
    call    run_ai
    call    yield
    jmp     .loop_forever_5

; deal with paddle collisions
task_paddle_collisions:
.loop_forever_6:
    call    deal_with_paddle_collisions
    call    yield
    jmp     .loop_forever_6


; Easy function: printing the board.
; run through all the variables and print them out.
; how hard could that be?
; I just need to update the screen memory, since there is already a thread which
; prints out the screen. Our screen is 80x25.
print_screen:
    call    reset_drawing_array
    call    print_score
    call    print_players
    call    print_ball
    call    copy_to_screen
    cmp     word [ball_dir], 0
    je      .ball_going_ne
    cmp     word [ball_dir], 1
    je      .ball_going_se
    cmp     word [ball_dir], 2
    je      .ball_going_sw
    cmp     word [ball_dir], 3
    je      .ball_going_nw
    jmp     .unknown_dir
.ball_going_ne:
    inc     word [ball_x]
    dec     word [ball_y]
    jmp     .unknown_dir
.ball_going_nw:
    dec     word [ball_x]
    dec     word [ball_y]
    jmp     .unknown_dir
.ball_going_se:
    inc     word [ball_x]
    inc     word [ball_y]
    jmp     .unknown_dir
.ball_going_sw:
    dec     word [ball_x]
    inc     word [ball_y]
    jmp     .unknown_dir
.unknown_dir:
    cmp     word [ball_x], 0
    je      .hit_left
    cmp     word [ball_y], 0
    je      .change_dir_top
    cmp     word [ball_x], 79
    jge     .hit_right               ; have this call add point to player
    cmp     word [ball_y], 24
    jge     .change_dir_bottom
    ; TODO add detection logic for paddles here
    jmp     .no_change_needed
.change_dir_top:
    cmp     word [ball_dir], 0
    je      .go_se
    jmp     .go_sw
.hit_left:
    mov     word [delta_computer_score], 1
    jmp     .reset_ball
.hit_right:
    mov     word [delta_player_score], 1
    jmp     .reset_ball
.change_dir_bottom:
    cmp     word [ball_dir], 2
    je      .go_nw
    jmp     .go_ne
.go_ne:
    mov     word [ball_dir], 0
    jmp     .no_change_needed
.go_se:
    mov     word [ball_dir], 1
    jmp     .no_change_needed
.go_nw:
    mov     word [ball_dir], 3
    jmp     .no_change_needed
.go_sw:
    mov     word [ball_dir], 2
    jmp     .no_change_needed
.reset_ball:
    mov     word [ball_x], 39
    mov     word [ball_y], 11
.no_change_needed:
    mov     ah, 0x86
    mov     dx, 0
    mov     cx, 5
    int     0x15
    ret

; prints the score
global print_score
print_score:
    mov     bx, 10                    ; you can assume that es has not been tampered with.
                                      ; also assume that the video text mode has been set.
    mov     word [screen+bx], 0x0748  ; Player: --> {0x53, 0x43, 0x4f, 0x52, 0x45, 0x7c, space}  player
    add     bx, 2
    mov     word [screen+bx], 0x0775  ; no blink. black background, non-bright white font.
    add     bx, 2
    mov     word [screen+bx], 0x076d
    add     bx, 2
    mov     word [screen+bx], 0x0761
    add     bx, 2
    mov     word [screen+bx], 0x076e
    add     bx, 2
    mov     word [screen+bx], 0x077c
    mov     cx, 0x0730              ; the '0' character
    add     cx, [player_score]
    add     bx, 4
    mov     word [screen+bx], cx

    mov     bx,  50                   ; you can assume that es has not been tampered with.
                                      ; also assume that the video text mode has been set.
    mov     word [screen+bx], 0x0743  ; SCORE: --> {0x53, 0x43, 0x4f, 0x52, 0x45, 0x7c, space}
    add     bx, 2
    mov     word [screen+bx], 0x076f  ; no blink. black background, non-bright white font.
    add     bx, 2
    mov     word [screen+bx], 0x076d
    add     bx, 2
    mov     word [screen+bx], 0x0770
    add     bx, 2
    mov     word [screen+bx], 0x0775
    add     bx, 2
    mov     word [screen+bx], 0x0774
    add     bx, 2
    mov     word [screen+bx], 0x0765
    add     bx, 2
    mov     word [screen+bx], 0x0772
    add     bx, 2
    mov     word [screen+bx], 0x077c
    mov     cx, 0x0730              ; the '0' character
    add     cx, [computer_score]
    add     bx, 4
    mov     word [screen+bx], cx
    ret

; prints the paddles
global print_players
print_players:
    mov     ax, 80                  ; multiplying to find the correct location to put the value.
    mov     dx, word [player_paddle_loc]
    imul    ax, dx
    mov     bx, ax
    mov     word [screen+bx], 0x07db          ; 0xa6 --> block
    add     bx, 80
    mov     word [screen+bx], 0x07db
    add     bx, 80
    mov     word [screen+bx], 0x07db
    mov     ax, 80                  ; multiplying to find the correct location to put the value.
    mov     dx, word [comput_paddle_loc]
    imul    ax, dx
    mov     bx, ax
    add     bx, 78
    mov     word [screen+bx], 0x07db          ; 0xdb --> block
    add     bx, 80
    mov     word [screen+bx], 0x07db
    add     bx, 80
    mov     word [screen+bx], 0x07db
    ret

; prints the ball
global print_ball
print_ball:
    mov     ax, 80                      ; multiplying to find the correct location to put the value.
    mov     dx, word [ball_y]
    imul    ax, dx
    mov     bx, ax                      ; y
    add     bx, [ball_x]                ; x
    mov     word [screen+bx], 0x07db    ; print (x, y)
    ret
reset_drawing_array:
    mov     cx, 0
    xor     bx, bx
.while:
    cmp     cx, 1000
    je      .end
    mov     word [screen + bx], 0
    add     bx, 2
    inc     cx
    jmp     .while
.end:
    ret
copy_to_screen:
    mov     ax, 0xB800
    mov     es, ax
    mov     cx, 0
    xor     bx, bx
.while:
    cmp     cx, 1000
    je      .end
    mov     ax, word [screen + bx]
    mov     [es:bx], ax
    add     bx, 2
    inc     cx
    jmp     .while
.end:
    ret


; updates paddle positions for pressing keys.
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
    jne     q_not_pressed                   ; add a cmp statement to test for extreems.  ;here now
    cmp     word [player_paddle_loc], 0     ; maybe not what you want to test.
    je      end_update
    mov     dx, [player_paddle_loc]
    sub     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
q_not_pressed:
    cmp     al, 97              ; a
    jne     a_not_pressed
    cmp     word [player_paddle_loc], 22    ; check paddle bounds.
    je      end_update
    mov     dx, [player_paddle_loc]
    add     dx, 1
    mov     [player_paddle_loc], dx
    jmp     end_update
a_not_pressed:
end_update:
    ret                     ; at the very least.

; Checks if there are any score developements to be updated and updates them.
global keep_score
keep_score:
    ; first update the player's score.
    mov     cx, [player_score]
    add     cx, [delta_player_score]
    mov     word [player_score], cx
    mov     word [delta_player_score], 0
    ; now update the computer's score
    mov     cx, [computer_score]
    add     cx, [delta_computer_score]
    mov     word [computer_score], cx
    mov     word [delta_computer_score], 0
    ; now check for game ending
    cmp     word [player_score], 5
    je      .clear_scores
    cmp     word [computer_score], 5
    je      .clear_scores
    jmp     .end_keep_score
.clear_scores:
    mov     word [player_score], 0
    mov     word [computer_score], 0
.end_keep_score:
    ret

; operates the AI paddle.
; every 17 moves, it skips. (so it's not invincible)
; otherwise, it just follows the ball.
global run_ai
run_ai:
    ; if the paddle is above the dot, move down,
    ; if it's below, move up.
    ; every once in a while, skip so it's not invincible.
    inc     word [ai_round_num]
    cmp     word [ai_round_num], 17
    jne     .do_ai
    mov     word [ai_round_num], 0
    jmp     .end_run_ai
.do_ai:
    mov     cx, [comput_paddle_loc]
    cmp     word [ball_y], cx
    jl      .move_down                                   ; if the ball is lower than the paddle
    cmp     word [comput_paddle_loc], 22                 ; move 'higher' if it's not already at the top
    je      .end_run_ai
    mov     cx, [comput_paddle_loc]
    add     cx, 1
    mov     [comput_paddle_loc], cx
    jmp     .end_run_ai
.move_down:
    cmp     word [comput_paddle_loc], 0
    je      .end_run_ai
    mov     cx, [comput_paddle_loc]
    sub     cx, 1
    mov     [comput_paddle_loc], cx
.end_run_ai:
    ret

; checks to see if the ball is near a paddle.
; if it is, then the ball is deflected.
global deal_with_paddle_collisions
deal_with_paddle_collisions:
    ; Check to see if it could be hitting player's paddle.
    cmp     word [ball_x], 1
    je      .check_for_player_collisions
    cmp     word [ball_x], 78
    jne     .no_collisions
    jmp     .check_for_computer_collisions
.no_collisions:
    jmp     .end_func
.check_for_player_collisions:
    mov     cx, [player_paddle_loc]
    cmp     word [ball_y], cx
    je      .player_collision
    inc     cx
    cmp     word [ball_y], cx
    je      .player_collision
    inc     cx
    cmp     word [ball_y], cx
    je      .player_collision
    jmp     .end_func                   ; no collisions

.player_collision:
    cmp     word [ball_dir], 3          ; going nw
    je      .go_ne                      ; I swoped these from how they were.
    jmp     .go_se
.go_se:
    inc     word [ball_x]
    dec     word [ball_y]
    mov     word [ball_dir], 1
    jmp     .end_func
.go_ne:
    inc     word [ball_x]
    inc     word [ball_y]
    mov     word [ball_dir], 0
    jmp     .end_func

.check_for_computer_collisions:
    mov     cx, [comput_paddle_loc]
    cmp     word [ball_y], cx
    je      .computer_collision
    inc     cx
    cmp     word [ball_y], cx
    je      .computer_collision
    inc     cx
    cmp     word [ball_y], cx
    je      .computer_collision
    jmp     .end_func                   ; no collisions

.computer_collision:
    cmp     word [ball_dir], 1          ; going se
    je      .go_sw                      ; I swopped these from how they were.
    jmp     .go_nw
.go_nw:
    dec     word [ball_x]               ; undo a move
    inc     word [ball_y]
    mov     word [ball_dir], 3
    jmp     .end_func
.go_sw:
    dec     word [ball_x]               ; undo a move. go_nw one step
    dec     word [ball_y]
    mov     word [ball_dir], 2
    jmp     .end_func

.end_func:
    ret

; plays the music.
global Play_Sound
Play_Sound:
    call play_B
    call mywait
    call yield

    call play_B
    call mywait
    call yield

    call play_B
    call mywait
    call yield

    call play_B
    call mywait
    call yield

    call play_B
    call mywait
    call yield

    call play_B
    call mywait
    call yield

    call play_D
    call mywait
    call yield

    call play_G
    call mywait
    call yield

    call play_A
    call mywait
    call yield

    call play_B
    call mywait
    call yield
    ret
mywait:
;        mov     ah, 0x86
;        mov     dx, 20
;        mov     cx, 0
;        int     0x15
        ret
play_B:
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
        ret
play_D:
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
        ret
play_G:
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
        ret
play_A:
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
        ret

SECTION .data
    ai_round_num: dw 0          ;
    player_paddle_loc: dw 12    ; [0, 22]
    player_score: dw 0          ;
    delta_player_score: dw 0    ;
    delta_computer_score: dw 0  ;
    computer_score: dw 0        ;
    ball_x: dw 40               ; even element of [0, 78]
    ball_y: dw 8                ; [0, 23]
    ball_dir: dw 2
    comput_paddle_loc: dw 15    ; [0, 22]
    task_main_str: db "I am task MAIN", 13, 10, 0
    screen: times 1000 dw 0
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

bits 16

org 0x100

SECTION .text
main:
    mov     byte [task_status], 1               ; set main task to active

    lea     di, [task_a]                        ; create task a
    call    spawn_new_task

    lea     di, [task_b]                        ; create task b
    call    spawn_new_task

.loop_forever_main:                             ; have main print for eternity
    lea     di, [task_main_str]
    call    putstring
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
    lea     di, [task_a_str]
    call    putstring
    call    yield
    jmp     .loop_forever_1
    ; does not terminate or return

task_b:
.loop_forever_2:
    lea     di, [task_b_str]
    call    putstring
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
; prints out the screen.
print_screen:
    ; first I print the score in the top corner.


    ; function body goes here

    mov    ax, [return value]
    ; remove local variables (if not using mov sp, bp to do so)
    ret


; need a function to move the ball one place.
; if the ball hits a wall, then check what wall it is.
; if it's the wall on the back side, then end the game.
; if it's a top or bottom wall, then just change the y direction.
; if it hits a paddle, change the x or y appriately.
; . . . this is the hard function.

SECTION .data
    player_paddle_loc: dw 128   ; 256 possible values.
    score: dw 100               ; start score at 100
    ball_x: dw 128
    ball_y: dw 128
    ball_dx: dw 1               ; {-2, -1, 0, 1, 2}
    ball_dy: dw 1               ; {-2, -1, 0, 1, 2}
    comput_paddle_loc: dw 128   ;

    current_task: dw 0 ; must always be a multiple of 2
    stacks: times (256 * 31) db 0 ; 31 fake stacks of size 256 bytes
    task_status: times 32 dw 0 ; 0 means inactive, 1 means active
    stack_pointers: dw 0 ; the first pointer needs to be to the real stack !
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

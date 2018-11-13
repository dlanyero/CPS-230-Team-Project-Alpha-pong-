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

    mov     word [es:bx+0], 0x9F42  ; B dark blue background, white font
    mov     word [es:bx+2], 0x9F4A  ; J dark blue background, white font
    mov     word [es:bx+4], 0x9F55  ; U dark blue background, white font
    mov     word [es:bx+6], 0x1F21  ; ! dark blue background, white font

    mov     ah, 0x0                 ; wait for user input
    int     0x16

    mov     ah, 0x4c                ; exit
    mov     al, 0
    int     0x21

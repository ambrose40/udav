; UDAV -- DOS .COM snake game, TASM/MASM syntax (8086 instructions).
; Build: TASM /l ZMEI.ASM   then   TLINK /t ZMEI.OBJ
;
; Mode 13h has 320x200 pixels. Each game cell occupies 2x2 pixels,
; so positions are packed as AH = cell row (0..99), AL = column (0..159).
; The bitmap's palette indices are also the game's collision/food map.

.model tiny
.code
org 100h

BOARD_COLUMNS       equ 160
BOARD_ROWS          equ 100
SCREEN_WIDTH        equ 320
VGA_SEGMENT         equ 0A000h
BITMAP_HEADER_SIZE  equ 1078       ; 14 + 40 bytes + 256 four-byte colors
BITMAP_PIXEL_COUNT  equ BOARD_COLUMNS * BOARD_ROWS
BITMAP_FILE_SIZE    equ BITMAP_HEADER_SIZE + BITMAP_PIXEL_COUNT
MAX_SNAKE_LENGTH    equ 1024
MIN_SNAKE_LENGTH    equ 2
INITIAL_LENGTH      equ 4
LAST_LEVEL          equ 4

COLOR_BACKGROUND    equ 0
COLOR_APPLE         equ 2          ; grow by one segment
COLOR_SHRINK        equ 3          ; discard tail as a green apple
COLOR_DOUBLE_APPLE  equ 4          ; grow by two segments
COLOR_SOLID         equ 15         ; walls and snake share this color

DIR_LEFT            equ 1
DIR_UP              equ 2
DIR_RIGHT           equ 3
DIR_DOWN            equ 4
STEP_ALIVE          equ 0
STEP_DEAD           equ 1
STEP_COMPLETE       equ 2

SCAN_ESCAPE         equ 01h
SCAN_F1             equ 3Bh
SCAN_F2             equ 3Ch
SCAN_F10            equ 44h
SCAN_UP             equ 48h
SCAN_LEFT           equ 4Bh
SCAN_RIGHT          equ 4Dh
SCAN_DOWN           equ 50h

startup proc near
    ; Own the stack instead of repeatedly resetting SP inside game routines.
    cli
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    sti
    mov ds,ax
    cld

    mov ah,0Fh
    int 10h
    and al,7Fh
    mov saved_video_mode,al
    mov ax,0013h
    int 10h

main_menu:
    mov dx,offset intro_filename
    call load_bitmap
    jnc show_menu
    jmp file_error
show_menu:
    call draw_bitmap
    call choose_speed
    cmp quit_requested,0
    je start_game
    jmp quit_game
start_game:
    mov current_level,1

start_level:
    call initialize_snake
    xor bx,bx
    mov bl,current_level
    dec bx
    shl bx,1
    mov dx,level_filenames[bx]
    call load_bitmap
    jnc show_level
    jmp file_error
show_level:
    call draw_bitmap
    ; Retain the original "press a key to start this level" pause.
    xor ah,ah
    int 16h
    cmp ah,SCAN_ESCAPE
    je quit_game
    cmp ah,SCAN_F10
    je quit_game
    call draw_snake

game_loop:
    call wait_for_move
    call read_direction
    cmp quit_requested,0
    jne quit_game
    call advance_snake
    cmp al,STEP_DEAD
    je game_lost
    cmp al,STEP_COMPLETE
    jne game_loop
    inc current_level
    cmp current_level,LAST_LEVEL
    jbe start_level

    mov dx,offset victory_filename
    jmp show_result
game_lost:
    mov dx,offset defeat_filename
show_result:
    call load_bitmap
    jc file_error
    call draw_bitmap
    ; F1/F2 start another game; Escape/F10 leave from result screens too.
    call choose_speed
    cmp quit_requested,0
    je start_game
quit_game:
    call restore_video_mode
    mov ax,4C00h
    int 21h

file_error:
    call restore_video_mode
    mov dx,offset file_error_message
    mov ah,09h
    int 21h
    mov si,current_filename
print_error_filename:
    lodsb
    or al,al
    jz finish_file_error
    mov dl,al
    mov ah,02h
    int 21h
    jmp print_error_filename
finish_file_error:
    mov dx,offset newline
    mov ah,09h
    int 21h
    mov ax,4C01h
    int 21h
startup endp

; Restore the mode active before launch, including when an asset cannot load.
restore_video_mode proc near
    xor ah,ah
    mov al,saved_video_mode
    int 10h
    ret
restore_video_mode endp

; Blocking menu input. F1 = two BIOS ticks/move; F2 = one tick/move.
; Other keys are ignored. Clobbers AX; updates move_delay/quit_requested.
choose_speed proc near
choose_speed_key:
    xor ah,ah
    int 16h
    cmp ah,SCAN_ESCAPE
    je choose_quit
    cmp ah,SCAN_F10
    je choose_quit
    cmp ah,SCAN_F1
    je choose_slow
    cmp ah,SCAN_F2
    jne choose_speed_key
    mov move_delay,1
    ret
choose_slow:
    mov move_delay,2
    ret
choose_quit:
    mov quit_requested,1
    ret
choose_speed endp

; Load one of the supplied 160x100, uncompressed, 8-bit BMPs.
; In: DS:DX = ASCIIZ filename. Out: CF set on open/read/format failure.
; Clobbers AX/BX/CX/DX/SI. Always closes an opened handle.
; The artwork deliberately uses file-row order as screen-row order, just as
; the original game did; do not reverse the usual bottom-up BMP scanlines.
load_bitmap proc near
    mov current_filename,dx
    mov ax,3D00h
    int 21h
    jc bitmap_open_failed
    mov bx,ax
    mov dx,offset bitmap_buffer
    mov cx,BITMAP_FILE_SIZE
    mov ah,3Fh
    int 21h
    ; Preserve both the read result and carry across DOS close.
    pushf
    push ax
    mov ah,3Eh
    int 21h
    pop ax
    popf
    jc bitmap_open_failed
    cmp ax,BITMAP_FILE_SIZE
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[0],4D42h ; "BM"
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[10],BITMAP_HEADER_SIZE
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[12],0
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[14],40
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[16],0
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[18],BOARD_COLUMNS
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[20],0
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[22],BOARD_ROWS
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[24],0
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[26],1  ; planes
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[28],8  ; bits/pixel
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[30],0  ; BI_RGB (no compression)
    jne bitmap_invalid
    cmp word ptr bitmap_buffer[32],0
    jne bitmap_invalid
    clc
    ret
bitmap_invalid:
    stc
bitmap_open_failed:
    ret
load_bitmap endp

; Draw the bitmap as 2x2 cells and count its food cells afresh.
; Uses the standard mode-13h palette, matching the original game.
; Clobbers AX/BX/DX/SI. draw_cell preserves the source pointer and position.
draw_bitmap proc near
    mov food_remaining,0
    mov si,offset bitmap_buffer + BITMAP_HEADER_SIZE
    xor bx,bx                       ; BH = row, BL = column
draw_bitmap_cell:
    mov dl,[si]
    cmp dl,COLOR_APPLE
    jb bitmap_cell_counted
    cmp dl,COLOR_DOUBLE_APPLE
    ja bitmap_cell_counted
    inc food_remaining
bitmap_cell_counted:
    mov ax,bx
    call draw_cell
    inc si
    inc bl
    cmp bl,BOARD_COLUMNS
    jb draw_bitmap_cell
    xor bl,bl
    inc bh
    cmp bh,BOARD_ROWS
    jb draw_bitmap_cell
    ret
draw_bitmap endp

; In: AX = packed cell position. Out: DI = top-left VGA byte offset.
; Preserves all other registers. Cell coordinates keep columns 128..159
; representable (their pixel coordinates exceed the old byte-sized x).
cell_video_offset proc near
    push ax
    push bx
    push dx
    xor bx,bx
    mov bl,al
    shl bx,1
    mov al,ah
    xor ah,ah
    mov di,SCREEN_WIDTH * 2
    mul di
    add ax,bx
    mov di,ax
    pop dx
    pop bx
    pop ax
    ret
cell_video_offset endp

; In: AX = packed cell, DL = color. Preserves all registers, including ES.
draw_cell proc near
    push ax
    push di
    push es
    call cell_video_offset
    mov ax,VGA_SEGMENT
    mov es,ax
    mov al,dl
    mov es:[di],al
    mov es:[di+1],al
    mov es:[di+SCREEN_WIDTH],al
    mov es:[di+SCREEN_WIDTH+1],al
    pop es
    pop di
    pop ax
    ret
draw_cell endp

; In: AX = packed cell. Out: AL = color; preserves all other registers.
read_cell proc near
    push di
    push es
    call cell_video_offset
    push ax
    mov ax,VGA_SEGMENT
    mov es,ax
    pop ax
    mov al,es:[di]
    pop es
    pop di
    ret
read_cell endp

; Initialize the original four-cell snake at pixel (128,128), facing left.
; Positions after snake_length are never read without first being filled.
initialize_snake proc near
    mov snake_length,INITIAL_LENGTH
    mov snake_direction,DIR_LEFT
    mov word ptr snake_cells[0],4040h
    mov word ptr snake_cells[2],4041h
    mov word ptr snake_cells[4],4042h
    mov word ptr snake_cells[6],4043h
    ret
initialize_snake endp

; Draw the complete snake once when entering a level. Clobbers AX/CX/DX/SI.
draw_snake proc near
    mov si,offset snake_cells
    mov cx,snake_length
    mov dl,COLOR_SOLID
draw_snake_cell:
    lodsw
    call draw_cell
    loop draw_snake_cell
    ret
draw_snake endp

; Consume at most one key per move so queued turns cannot reverse the snake
; before it moves. In particular, an immediate 180-degree turn is ignored.
; Clobbers AX/BX. Escape and the original F10 binding both quit.
read_direction proc near
    mov ah,01h
    int 16h
    jz direction_done
    xor ah,ah
    int 16h
    cmp ah,SCAN_ESCAPE
    je direction_quit
    cmp ah,SCAN_F10
    je direction_quit
    mov bl,DIR_LEFT
    cmp ah,SCAN_LEFT
    je direction_candidate
    mov bl,DIR_UP
    cmp ah,SCAN_UP
    je direction_candidate
    mov bl,DIR_RIGHT
    cmp ah,SCAN_RIGHT
    je direction_candidate
    mov bl,DIR_DOWN
    cmp ah,SCAN_DOWN
    jne direction_done
direction_candidate:
    mov al,snake_direction
    sub al,bl
    cmp al,2
    je direction_done
    cmp al,-2
    je direction_done
    mov snake_direction,bl
direction_done:
    ret
direction_quit:
    mov quit_requested,1
    ret
read_direction endp

; Advance one cell, handle food, shift the body, and update changed cells.
; Out: AL = STEP_ALIVE / STEP_DEAD / STEP_COMPLETE. Clobbers general regs.
; The VGA screen remains the collision map, as in the original game.
advance_snake proc near
    mov ax,snake_cells[0]
    cmp snake_direction,DIR_LEFT
    jne move_up_test
    or al,al
    jz move_dead
    dec al
    jmp next_head_ready
move_up_test:
    cmp snake_direction,DIR_UP
    jne move_right_test
    or ah,ah
    jz move_dead
    dec ah
    jmp next_head_ready
move_right_test:
    cmp snake_direction,DIR_RIGHT
    jne move_down
    inc al
    cmp al,BOARD_COLUMNS
    jae move_dead
    jmp next_head_ready
move_down:
    inc ah
    cmp ah,BOARD_ROWS
    jae move_dead
next_head_ready:
    mov next_head,ax
    call read_cell
    cmp al,COLOR_SOLID
    je move_dead
    mov cx,snake_length
    cmp al,COLOR_APPLE
    je eat_apple
    cmp al,COLOR_DOUBLE_APPLE
    je eat_double_apple
    cmp al,COLOR_SHRINK
    je eat_shrink

    ; No growth: erase the tail before shifting it out of the body.
    call erase_tail
    jmp shift_body
move_dead:
    mov al,STEP_DEAD
    ret

eat_double_apple:
    inc cx
eat_apple:
    inc cx
    cmp cx,MAX_SNAKE_LENGTH
    jbe growth_bounded
    mov cx,MAX_SNAKE_LENGTH
growth_bounded:
    dec food_remaining
    ; Fill any extra slots with the old tail. A two-cell growth keeps one
    ; duplicate tail position for a move, then unfolds naturally.
    mov bx,snake_length
    dec bx
    shl bx,1
    mov ax,snake_cells[bx]
    mov dx,cx
    sub dx,snake_length
    jz growth_at_capacity
fill_growth:
    add bx,2
    mov snake_cells[bx],ax
    dec dx
    jnz fill_growth
    jmp shift_body
growth_at_capacity:
    ; A capped snake still moves normally and consumes the food.
    call erase_tail
    jmp shift_body

eat_shrink:
    cmp cx,MIN_SNAKE_LENGTH
    jbe shrink_at_minimum
    ; Preserve the original castor-oil mechanic: the discarded last cell
    ; becomes green food. One item eaten + one spawned = unchanged count.
    mov bx,cx
    dec bx
    shl bx,1
    mov ax,snake_cells[bx]
    mov dl,COLOR_APPLE
    call draw_cell
    dec cx
    sub bx,2
    cmp ax,snake_cells[bx]
    je shift_body                  ; double growth may have duplicated tail
    mov ax,snake_cells[bx]
    mov dl,COLOR_BACKGROUND
    call draw_cell
    jmp shift_body
shrink_at_minimum:
    ; Consume the item without shrinking below a playable two-cell body.
    dec food_remaining
    call erase_tail

shift_body:
    mov snake_length,cx
    ; Copy backwards because the source and destination overlap.
    dec cx
    mov bx,cx
    shl bx,1
    mov si,offset snake_cells
    add si,bx
    mov di,si
    sub si,2
    push es
    push ds
    pop es
    std
    rep movsw
    cld
    pop es
    mov ax,next_head
    mov snake_cells[0],ax
    mov dl,COLOR_SOLID
    call draw_cell
    mov al,STEP_ALIVE
    cmp food_remaining,0
    jne advance_done
    mov al,STEP_COMPLETE
advance_done:
    ret
advance_snake endp

; Erase the current tail. CX (the requested new length) is preserved.
; Clobbers AX/BX/DX. With double growth the last two entries may overlap;
; do not erase a cell that the penultimate segment still occupies.
erase_tail proc near
    mov bx,snake_length
    dec bx
    shl bx,1
    mov ax,snake_cells[bx]
    cmp ax,snake_cells[bx-2]
    je tail_erased
    mov dl,COLOR_BACKGROUND
    call draw_cell
tail_erased:
    ret
erase_tail endp

; Wait for one or two BIOS timer transitions (~18.2 ticks/second).
; Comparing successive ticks rather than a target timestamp handles both
; the low-word wrap and the BIOS midnight reset. AH is set on EVERY call.
; Clobbers AX/BX/CX/DX/SI/DI.
wait_for_move proc near
    mov bx,move_delay
    xor ah,ah
    int 1Ah
    mov si,cx
    mov di,dx
wait_next_tick:
    xor ah,ah
    int 1Ah
    cmp cx,si
    jne timer_changed
    cmp dx,di
    je wait_next_tick
timer_changed:
    mov si,cx
    mov di,dx
    dec bx
    jnz wait_next_tick
    ret
wait_for_move endp

; All game state is owned by labels, not absolute DS offsets.
saved_video_mode db 3
quit_requested   db 0
current_level    db 1
snake_direction  db DIR_LEFT
move_delay       dw 2
snake_length     dw INITIAL_LENGTH
food_remaining   dw 0
next_head        dw 0
current_filename dw 0

intro_filename   db 'intro0.bmp',0
defeat_filename  db 'losezz.bmp',0
victory_filename db 'victor.bmp',0
level1_filename  db 'level1.bmp',0
level2_filename  db 'level2.bmp',0
level3_filename  db 'level3.bmp',0
level4_filename  db 'level4.bmp',0
level_filenames  dw offset level1_filename, offset level2_filename
                 dw offset level3_filename, offset level4_filename
file_error_message db 'Cannot read a 160x100 uncompressed 8-bit game bitmap: $'
newline          db 13,10,'$'

; Keep buffers and a private stack inside the single .COM segment. Their
; combined size leaves ample space below DOS's 64 KiB segment limit.
snake_cells      dw MAX_SNAKE_LENGTH dup (0)
bitmap_buffer    db BITMAP_FILE_SIZE dup (0)
                 db 512 dup (0)
stack_top label word

end startup

.model tiny
assume cs:progg

progg segment
org 100h

;----------------------------------------------------------------------------
startup proc
;jmp check_speed
mov word ptr [ds:1960h],0000h
jmp set_video

;jmp set_video
ret
startup endp


;----------------------------------------------------------------------------
defeat:
mov sp,00h
mov word ptr [ds:1960h],0000h
mov word ptr [ds:1970h],0000h
lea dx,filenamed
mov [ds:1802h],dx
jmp read_file

;----------------------------------------------------------------------------
set_video:
;mov ax,4F02h
;mov bx,100h

mov ah,00h
mov al,13h
int 10h
jmp intro

;----------------------------------------------------------------------------
apple_check:
mov si,[ds:1800h]
cmp si,00h
jz konec
jmp not_finished
konec:
jmp set_param
;mov cx,0000h
;mov dx,0000h
;chknext:
;mov sp,00h
;mov ah,0Dh
;int 10h
;cmp al,00h
;ja onemchk
;jmp gotov
;onemchk:
;cmp al,0Fh
;jnb gotov
;jmp not_finished
;gotov:
;add cx,02h
;cmp cx,0140h
;jnz more2
;mov cx,00h
;add dx,02h
;cmp dx,00C8h
;jz orev2
;more2:
;jmp chknext
;orev2:
;jmp set_param




;----------------------------------------------------------------------------
read_file:
mov dx,[ds:1802h]
mov ax,3D00h
xor cx,cx
int 21h
mov dx,1A20h
mov bx,ax
mov cx,42B6h
mov ah,3Fh
int 21h
mov ax,3E00h
int 21h
jmp draw_apples

;----------------------------------------------------------------------------
intro:
lea dx,filenamei
mov [ds:1802h],dx
jmp read_file

;Входные данные: x в AX, y в BX, цвет в CX
;Выходные данные: регистры AX и BX не сохраняются
draw_pix:
;push bx
mov di,cx
mov bx,dx
xchg BH,BL ;умножаем y на 256, BL=0
add di,BX  ;AX = x+256y
shr BX,1   ;делим 256y на два
shr BX,1   ;BX = 256y/4 = 64y
add BX,di  ;BX = x+320y
mov di,ES ;сохраняем значение ES
mov si,0A000h  ;сегмент памяти экрана VGA
mov es,si
mov ES:[BX],al  ;выводим байт на экран
mov ES,di ;восстанавливаем значение регистра ES
;pop bx
ret


;----------------------------------------------------------------------------
draw_apples:
mov cx,0000h
mov dx,0000h
mov bx,1E56h
drawnext:
;mov ah,0Ch
mov al,[bx]
cmp al,02h
jnz netoo
mov si,[ds:1800h]
inc si
mov [ds:1800h],si
netoo:
cmp al,03h
jnz netoo2
mov si,[ds:1800h]
inc si
mov [ds:1800h],si
netoo2:
cmp al,04h
jnz netoo3
mov si,[ds:1800h]
inc si
mov [ds:1800h],si
netoo3:
;mov ah,0Ch


mov al,[bx]
push bx
;int 10h
call draw_pix

inc cx
;mov ah,0Ch
;mov al,[ds:bx]
call draw_pix
;int 10h
inc dx
;mov ah,0Ch
;mov al,[ds:bx]
call draw_pix
;int 10h
dec cx
;mov ah,0Ch
;mov al,[ds:bx]
call draw_pix
;int 10h
pop bx
mov sp,00h
inc bx
dec dx
add cx,02h
cmp cx,0140h
jnz more
mov cx,00h
add dx,02h
cmp dx,00C8h
jz orev
more:
jmp drawnext
orev:
mov bx,[ds:1970h]
cmp bx,0F3h
jnz nodraws
mov ax,0000h
int 16h
jmp draw_snake
nodraws:
mov word ptr [ds:1970h],00F3h
jmp choice
;jmp set_param


;----------------------------------------------------------------------------
choice:
mov ah,00h
int 16h
cmp ah,01h
jnz drugkn1
jmp exit
drugkn1:
cmp ah,3Bh
jnz drugkn2
mov word ptr [ds:1900h],02h
jmp set_param
drugkn2:
cmp ah,3Ch
jnz drugkn3
mov word ptr [ds:1900h],01h
jmp set_param
drugkn3:
jmp choice

;----------------------------------------------------------------------------
kastorka:
mov dx,1000h
mov ax,0000h
mov al,[ds:1930h]
mov cl,02h
mul cl
add ax,dx
mov bx,ax
mov ax,[bx]
mov cx,0000h
mov dx,0000h
mov cl,al
mov dl,ah
;add cl,01h
mov ah,0Ch
mov al,02h
int 10h
inc cl
mov ah,0Ch
mov al,02h
int 10h
inc dl
mov ah,0Ch
mov al,02h
int 10h
dec cl
mov ah,0Ch
mov al,02h
int 10h
jmp return

;----------------------------------------------------------------------------
draw_snake:
mov bx,[ds:1928h]
mov ax,[bx]
mov cx,0000h
mov dx,0000h
mov cl,al
mov dl,ah
mov al,[ds:1939h]
cmp al,00h
jz skiper
mov al,0Fh
skiper:
call draw_pix
;mov ah,0Ch
;int 10h
inc cl
call draw_pix
;mov ah,0Ch
;int 10h
inc dl
call draw_pix
;mov ah,0Ch
;int 10h
dec cl
call draw_pix
;mov ah,0Ch
;int 10h
mov cx,[ds:1000h]
inc cx
mov [ds:1000h],cx
mov dx,[ds:1930h]
cmp cx,dx
jae skip
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
jmp draw_snake
skip:
mov ax,[ds:1938h]
cmp ax,0000h
jz toend
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
mov word ptr [ds:1938h],0000h
mov cx,[ds:1000h]
dec cx
mov [ds:1000h],cx
jmp draw_snake
toend:
mov word ptr [ds:1928h],1002h
mov word ptr [ds:1938h],0F00h
mov word ptr [ds:1000h],0000h
jmp Snake_moves

;----------------------------------------------------------------------------
exit:
mov sp,00h
int 20h

;----------------------------------------------------------------------------
set_param:
mov word ptr [ds:1000h],0000h
mov word ptr [ds:1002h],8080h
mov word ptr [ds:1004h],8082h
mov word ptr [ds:1006h],8084h
mov word ptr [ds:1008h],8086h
mov bx,1008h
yeshcho:
add bx,02h
mov [bx],0FFFFh
cmp bx,17FEh
jb yeshcho
mov word ptr [ds:1926h],0800h
mov word ptr [ds:1928h],1002h
mov word ptr [ds:1930h],0004h
mov word ptr [ds:1932h],0001h
mov word ptr [ds:1938h],0F00h
mov word ptr [ds:1800h],0000h
mov word ptr [ds:1940h],0000h
mov bx,[ds:1960h]
add bx,0Bh
cmp bx,037h
jbe nextlev
mov bx,0000h 
nextlev:
mov [ds:1960h],bx
lea dx,filenamei+bx
mov [ds:1802h],dx
jmp read_file

;----------------------------------------------------------------------------
snake_moves:
push ax
push bx
push cx
mov ax,[ds:1002h]
mov cx,0000h
mov dx,0000h
mov cl,al
mov dl,ah
mov ax,[ds:1932h]
cmp ax,0001h
jnz drugoi
dec cl
dec cl
drugoi:
mov ax,[ds:1932h]
cmp ax,0002h
jnz drugoi2
dec dl
dec dl
drugoi2:
mov ax,[ds:1932h]
cmp ax,0003h
jnz drugoi3
inc cl
inc cl
drugoi3:
mov ax,[ds:1932h]
cmp ax,0004h
jnz drugoi4
inc dl
inc dl
drugoi4:
mov ah,0Dh
int 10h
cmp al,02h
jnz noapple
mov dx,[ds:1930h]
inc dx
mov si,[ds:1800h]
dec si
mov [ds:1800h],si
mov [ds:1930h],dx
noapple:
cmp al,04h
jnz noapple2
mov dx,[ds:1930h]
inc dx
inc dx
mov si,[ds:1800h]
dec si
mov [ds:1800h],si
mov [ds:1930h],dx
noapple2:
cmp al,03h
jnz noapple3
jmp kastorka
return:
mov dx,[ds:1930h]
dec dx
mov [ds:1930h],dx
noapple3:
cmp al,0Fh
jnz noapple4
jmp defeat
noapple4:
jmp apple_check
not_finished:
mov cx,[ds:1932h]
cmp cx,0001h
jnz another1
mov bx,[ds:1928h]
mov dx,[bx]
mov [ds:1940h],dx
dec dl
dec dl
mov [bx],dx
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
again1:
mov bx,[ds:1928h]
mov dx,[bx]
mov ax,[ds:1940h]
mov [ds:1940h],dx
mov [bx],ax
mov cx,[ds:1000h]
inc cx
mov [ds:1000h],cx
mov dx,[ds:1930h]
cmp cx,dx
jz skip1
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
jmp again1
skip1:
mov [ds:1928h],1002h
another1:
mov cx,[ds:1932h]
cmp cx,0002h
jnz another2
mov bx,[ds:1928h]
mov dx,[bx]
mov [ds:1940h],dx
dec dh
dec dh
mov [bx],dx
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
again2:
mov bx,[ds:1928h]
mov dx,[bx]
mov ax,[ds:1940h]
mov [ds:1940h],dx
mov [bx],ax
mov cx,[ds:1000h]
inc cx
mov [ds:1000h],cx
mov dx,[ds:1930h]
cmp cx,dx
jz skip2
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
jmp again2
skip2:
mov [ds:1928h],1002h
another2:
mov cx,[ds:1932h]
cmp cx,0003h
jnz another3
mov bx,[ds:1928h]
mov dx,[bx]
mov [ds:1940h],dx
inc dl
inc dl
mov [bx],dx
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
again3:
mov bx,[ds:1928h]
mov dx,[bx]
mov ax,[ds:1940h]
mov [ds:1940h],dx
mov [bx],ax
mov cx,[ds:1000h]
inc cx
mov [ds:1000h],cx
mov dx,[ds:1930h]
cmp cx,dx
jz skip3
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
jmp again3
skip3:
mov [ds:1928h],1002h
another3:
mov cx,[ds:1932h]
cmp cx,0004h
jnz another4
mov bx,[ds:1928h]
mov dx,[bx]
mov [ds:1940h],dx
inc dh
inc dh
mov [bx],dx
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
again4:
mov bx,[ds:1928h]
mov dx,[bx]
mov ax,[ds:1940h]
mov [ds:1940h],dx
mov [bx],ax
mov cx,[ds:1000h]
inc cx
mov [ds:1000h],cx
mov dx,[ds:1930h]
cmp cx,dx
jz skip4
mov bx,[ds:1928h]
inc bx
inc bx
mov [ds:1928h],bx
jmp again4
skip4:
mov [ds:1928h],1002h
another4:
mov ax,0100h
int 16h
mov bx,ax
mov ax,0000h
LAHF
cmp ah,46h
jz getto3
mov ah,00h
int 16h
cmp ah,01h
jnz proced
jmp exit
proced:
cmp ah,4Bh
jnz getto
mov bx,[ds:1932h]
cmp bx,0003h
jz getto
mov word ptr [ds:1932h],0001h
getto:
cmp ah,4Dh
jnz getto1
mov bx,[ds:1932h]
cmp bx,0001h
jz getto1
mov word ptr [ds:1932h],0003h
getto1:
cmp ah,50h
jnz getto2
mov bx,[ds:1932h]
cmp bx,0002h
jz getto2
mov word ptr [ds:1932h],0004h
getto2:
cmp ah,48h
jnz getto3
mov bx,[ds:1932h]
cmp bx,0004h
jz getto3
mov word ptr [ds:1932h],0002h
getto3:
pop cx
pop bx
pop ax
mov word ptr [ds:1000h],0000h
mov sp,00h
mov bx,0000h
mov cx,0000h
;jmp draw_snake
jmp slow_down
;jmp check_speed

;----------------------------------------------------------------------------
slow_down:
mov ah,00h
int 1Ah
mov bx,[ds:1900h]
add dx,bx
adc cx,00h
mov di,dx
mov si,cx
repet:
int 1Ah
cmp cx,si
jae onemoprov
jmp repet
onemoprov:
cmp dx,di
jb repet
jmp draw_snake

tick0 dw 0,0
tick2 dw 0,0
filenamed db 'losezz.bmp',0
filenamei db 'intro0.bmp',0
filename1 db 'level1.bmp',0
filename2 db 'level2.bmp',0
filename3 db 'level3.bmp',0
filename4 db 'level4.bmp',0
filename5 db 'victor.bmp',0
progg ends
end startup
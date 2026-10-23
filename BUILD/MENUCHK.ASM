.model tiny
.code
org 100h
start:
    mov ax,0040h
    mov es,ax
    mov ax,es:[001Ah]
    cmp ax,es:[001Ch]
    jne failed
    mov dx,offset passed_message
    mov ah,09h
    int 21h
    mov ax,4C00h
    int 21h
failed:
    mov dx,offset failed_message
    mov ah,09h
    int 21h
    mov ax,4C01h
    int 21h
passed_message db 'PASS: all scripted menu and game keys consumed',13,10,'$'
failed_message db 'FAIL: scripted keys remain in BIOS buffer',13,10,'$'
end start

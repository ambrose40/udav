; Local DOSBox smoke-test helper: queue F2, Space, Escape in the BIOS buffer.
.model tiny
.code
org 100h
start:
    mov ax,0040h
    mov es,ax
    pushf
    cli
    mov word ptr es:[001Ah],001Eh
    mov word ptr es:[001Ch],0024h
    mov word ptr es:[001Eh],3C00h
    mov word ptr es:[0020h],3920h
    mov word ptr es:[0022h],011Bh
    popf
    mov ax,4C00h
    int 21h
end start

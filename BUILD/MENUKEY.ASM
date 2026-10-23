; Local smoke check: build/run, run existing, build only, logs, return.
.model tiny
.code
org 100h
start:
    mov ax,0040h
    mov es,ax
    pushf
    cli
    mov word ptr es:[001Ah],001Eh
    mov word ptr es:[001Ch],0038h
    mov word ptr es:[001Eh],0231h
    mov word ptr es:[0020h],3C00h
    mov word ptr es:[0022h],3920h
    mov word ptr es:[0024h],011Bh
    mov word ptr es:[0026h],0433h
    mov word ptr es:[0028h],3C00h
    mov word ptr es:[002Ah],3920h
    mov word ptr es:[002Ch],011Bh
    mov word ptr es:[002Eh],0332h
    mov word ptr es:[0030h],3920h
    mov word ptr es:[0032h],0534h
    mov word ptr es:[0034h],3920h
    mov word ptr es:[0036h],0635h
    popf
    mov ax,4C00h
    int 21h
end start

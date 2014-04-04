        title   RLINE --- read text file
        page    55,132
	.286

; RLINE.ASM --- read line from text file (OS/2 version)
; by Ray Duncan, (C) 1988 Ziff Davis Communications
;
; Call with:    DS:DX = buffer address
;               CX    = buffer size
;               BX    = text file handle
;               
;               Buffer should be larger than any line that
;               will be encountered in the text file.
;
; Returns:      AX    = length of line including new-line
;                       delimiter character(s), or 0 if 
;                       end of file or no delimiter found.
;               DS:DX = text address
;
;               Other registers preserved.      

	extrn	DosRead:far
	extrn	DosChgFilePtr:far

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

nl      db      0dh,0ah                 ; OS/2 logical new-line
nl_len  equ     $-nl

rlen	dw	0			; receives count from DosRead
newfp	dd	0			; receives absolute filepointer

_DATA   ends

_TEXT   segment word public 'CODE'

        extrn   strndx:near             ; string search utility

        assume  cs:_TEXT,ds:DGROUP,es:DGROUP

        public  rline
rline   proc    near

        push    bx                      ; save registers
        push    cx
        push    dx
        push    si
        push    di
        push    es

                                        ; read chunk from file...
	push	bx			; file handle
        push	ds			; buffer address
        push	dx
	push	cx			; length to read
        push	ds		        ; receives actual length
        push	offset DGROUP:rlen	
        call	DosRead	        	; transfer to OS/2
	or	ax,ax		        ; read successful?
        jnz	rline1                  ; jump if read error
        cmp	rlen,0			; end of file?
        jz      rline1                  ; yes, jump

        push    bx                      ; save input file handle
        push    dx                      ; save buffer base address
        push    ds

        push    ds                      ; set up for delimiter search
        pop     es                      ; ES:DI = string to search
        push    dx
        pop     di
        mov     dx,rlen			; DX = string length
        mov     si,DGROUP               ; DS:SI = delimiter address
        mov     ds,si
        mov     si,offset DGROUP:nl
        mov     bx,nl_len               ; BX = delimiter length 
        call    strndx                  ; search for delimiter

        pop     ds                      ; restore buffer base address
        pop     dx
        pop     bx                      ; restore input file handle
        jc      rline1                  ; jump if no delimiter found

        add     di,nl_len               ; calculate line length
        sub     di,dx

	mov	ax,rlen			; calculate read excess
        sub     ax,di
        neg     ax
        cwd

					; now back up file pointer
	push	bx			; file handle
        push	dx			; number of bytes
        push	ax
        push	1			; method = rel. to current FP
	push	ds   			; receives absolute filepointer
        push	offset DGROUP:newfp
	call	DosChgFilePtr

        mov     ax,di                   ; return line length in AX
        jmp     rline2

rline1: xor     ax,ax                   ; end of file or other error,
                                        ; set line length = 0

rline2: pop     es                      ; restore registers
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret                             ; return line length

rline   endp

_TEXT   ends
        
        end


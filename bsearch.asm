        title   BSEARCH binary search engine
        page    55,132
        .286

; BSEARCH.ASM --- General purpose binary search routine (OS/2 version)
; by Ray Duncan, Copyright 1988 Ziff Davis Communications
;
; Call with:    BX    = file handle
;               CX    = record length
;               DS:DX = record buffer address
;               SI    = first (left) record number
;               DI    = last (right) record number
;               ES:BP = key structure address
;
;               where the key structure is:
;               dw    n          length of key
;               dw    m          offset of key in record
;               db    n dup (?)  key value
;
; Returns:      if record found
;               Zero flag = set
;               AX    = record number
;
;               if record not found
;               Zero flag = clear
;               AX    = undefined
;
;               All other registers preserved

        extrn   DosChgFilePtr:far       ; references to OS/2 API
        extrn   DosRead:far

_TEXT   segment word public 'CODE'

        extrn   strcmp:near

        assume  cs:_TEXT

rlen    equ     word ptr [bp-6]         ; receives DosRead length
fptr    equ     word ptr [bp-4]
kbuff   equ     dword ptr [bp]          ; key address
right   equ     word ptr [bp+4]         ; last record number
left    equ     word ptr [bp+6]         ; first record number
fbuff   equ     dword ptr [bp+8]        ; file buffer address
flen    equ     word ptr [bp+12]        ; file record size
fhandle equ     word ptr [bp+14]        ; file handle

        public  bsearch 
bsearch proc    near

        cmp     si,di                   ; first > last record?
        jng     bsch1                   ; no, jump
        ret                             ; record absent, end search

bsch1:  push    bx                      ; save registers
        push    cx
        push    ds
        push    dx
        push    si
        push    di
        push    es
        push    bp
        mov     bp,sp                   ; point to stack frame
        sub     sp,6                    ; allocate local variables

        mov     ax,si                   ; calculate record number
        add     ax,di                   ; at middle of file segment             
        shr     ax,1                    ; (left + right) / 2
        push    ax                      ; save record number
        mul     cx                      ; DX:AX := file offset

                                        ; set file pointer...
        push    bx                      ; file handle
        push    dx                      ; file offset
        push    ax
        push    0                       ; method = rel. to start of file
        push    ss                      ; receives absolute file ptr
        lea     ax,fptr
        push    ax
        call    DosChgFilePtr           ; transfer to OS/2

                                        ; now read record...
        push    bx                      ; file handle
        lds     dx,fbuff                ; address of record buffer
        push    ds
        push    dx
        push    flen                    ; length of record
        push    ss                      ; receives actual bytes read
        lea     ax,rlen
        push    ax
        call    DosRead                 ; transfer to OS/2

        les     di,kbuff                ; ES:DI = key structure
        mov     si,dx                   ; DS:SI = record buffer
        add     si,es:[di+2]            ; DS:SI = key within record
        mov     bx,es:[di]              ; BX = length of key
        mov     dx,bx                   ; DS = length of key
        add     di,4                    ; ES:DI = address of key
        call    strcmp                  ; now compare keys

        pop     ax                      ; recover record number
        jz      bsch4                   ; match found, exit

        push    bp                      ; save stack frame pointer
        mov     bx,fhandle              ; set up to bisect file and
        mov     cx,flen                 ; perform recursive search
        mov     si,left
        mov     di,right
        lds     dx,fbuff
        les     bp,kbuff
        jl      bsch2                   ; branch on key comparison

        mov     di,ax                   ; record < search key
        dec     di                      ; set right = current - 1
        jmp     bsch3

bsch2:  mov     si,ax                   ; record > search key
        inc     si                      ; set left = current + 1

bsch3:  call    bsearch                 ; inspect next middle record
        pop     bp                      ; restore stack frame pointer

bsch4:  mov     sp,bp                   ; discard local variables
        pop     bp                      ; restore registers     
        pop     es                      ; leaving Z flag undisturbed
        pop     di
        pop     si
        pop     dx
        pop     ds
        pop     cx
        pop     bx

        ret                             ; and return to caller

bsearch endp

_TEXT   ends

        end


        title   TRYBSRCH Demo of BSEARCH routine
        page    55,132
        .286

; TRYBSRCH.ASM  Demo of BSEARCH routine (OS/2 version),
;               searches file previously created by MAKENIF.EXE.        
; by Ray Duncan, Copyright (C) 1988 Ziff Davis Communications
;
; The user is prompted to enter a search key.  The first
; 8 characters of the key are used to search TESTFILE.DAT,
; using the binary search algorithm.  The success or failure 
; of the search is reported along with the record number (if found).
;
; Each record in TESTFILE.DAT is RSIZE bytes long.  Bytes 
; 0 to (KSIZE-1) of the record are the ASCII key for searches
; by BSEARCH.  Bytes KSIZE to (RSIZE-1) of the record
; are initialized to zero and are not used.  RSIZE, KSIZE,
; and the key offset within the record must be kept synchronized
; with MAKENIF.C.
;
; To build TRYBSRCH.EXE you also need TRYBSRCH.DEF, BSEARCH.ASM, 
; ITOA.ASM, and STRINGS1.ASM.  Enter the following commands:
;
;       MASM TRYBSRCH;
;       MASM BSEARCH;
;       MASM ITOA;
;       MASM STRINGS1;
;       LINK TRYBSRCH+BSEARCH+ITOA+STRINGS1,,,OS2,TRYBSRCH.DEF;

stdin   equ     0                       ; standard input handle
stdout  equ     1                       ; standard output handle

cr      equ     0dh                     ; ASCII carriage return
lf      equ     0ah                     ; ASCII line feed
blank   equ     20h                     ; ASCII blank

rsize   equ     64                      ; TESTFILE.DAT record size
ksize   equ     8                       ; TESTFILE.DAT key size
koffs   equ     0                       ; offset of key within record

        extrn   DosChgFilePtr:far       ; references to OS/2 API
        extrn   DosClose:far
        extrn   DosExit:far
        extrn   DosOpen:far
        extrn   DosRead:far
        extrn   DosWrite:far

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

fname   db      'TESTFILE.DAT',0        ; file created by MAKENIF.C
fhandle dw      ?                       ; handle for TESTFILE.DAT
faction dw      ?                       ; receives DosOpen action
frecs   dw      ?                       ; records in file
fbuff   db      rsize dup (0)           ; file record buffer
fsize   dd      ?                       ; filesize in bytes

key     dw      ksize                   ; length of key data
        dw      koffs                   ; offset of key within record
kval    db      80 dup (0)              ; actual key data

rlen    dw      ?                       ; receives length from DosRead
wlen    dw      ?                       ; receives length from DosWrite

msg1    db      cr,lf
        db      'Can''t open TESTFILE.DAT'
        db      cr,lf
msg1_len equ $-msg1

msg2    db      cr,lf
        db      'Enter search key: '
msg2_len equ $-msg2

msg3    db      cr,lf
        db      'Record number is: '
msg3a   db      6 dup (blank)
        db      cr,lf
msg3_len equ $-msg3

msg4    db      cr,lf
        db      'Record not found'
        db      cr,lf
msg4_len equ $-msg4

_DATA   ends


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:_DATA

        extrn   itoa:near
        extrn   bsearch:near

main    proc    near

        push    ds                      ; let ES point to DGROUP too
        pop     es

        cld                             ; string ops safety first

                                        ; open the file TESTFILE.DAT...
        push    ds                      ; address of filename
        push    offset DGROUP:fname
        push    ds                      ; receives file handle
        push    offset DGROUP:fhandle
        push    ds                      ; receives DosOpen action
        push    offset DGROUP:faction
        push    0                       ; file allocation (N/A)
        push    0
        push    0                       ; file attribute (N/A)
        push    1                       ; open only if already exists
        push    20h                     ; read-only, deny write
        push    0                       ; reserved DWORD 0
        push    0
        call    DosOpen                 ; transfer to OS/2
        or      ax,ax                   ; open successful?
        jz      main1                   ; yes, jump

                                        ; open failed, display error
                                        ; message and exit...
        push    stdout                  ; standard output handle
        push    ds                      ; message address
        push    offset DGROUP:msg1
        push    msg1_len                ; message length
        push    ds                      ; receives actual bytes writen
        push    offset DGROUP:wlen
        call    DosWrite                ; transfer to OS/2
        jmp     main4                   ; go perform final exit

main1:                                  ; find filesize in bytes...
        push    fhandle                 ; file handle
        push    0                       ; relative offset = 0
        push    0
        push    2                       ; method = rel. to end of file
        push    ds                      ; receives file size
        push    offset DGROUP:fsize
        call    DosChgFilePtr           ; transfer to OS/2
        
        mov     ax,word ptr fsize       ; calculate number of records
        mov     dx,word ptr fsize+2
        mov     bx,rsize                ; filesize / bytes per record
        div     bx                      ; = records in file
        mov     frecs,ax
        
                                        ; display "Enter search key: "
main2:  push    stdout                  ; standard output handle
        push    ds                      ; message address
        push    offset DGROUP:msg2
        push    msg2_len                ; message length
        push    ds                      ; receives actual bytes written
        push    offset DGROUP:wlen
        call    DosWrite                ; transfer to OS/2

        mov     cx,ksize                ; zero out previous key
        mov     di,offset kval
        xor     al,al
        rep stosb

        mov     cx,6                    ; remove previous record
        mov     di,offset msg3a         ; number from output string
        mov     al,blank
        rep stosb

                                        ; get search key from user...
        push    stdin                   ; standard input handle
        push    ds                      ; input buffer address
        push    offset DGROUP:kval
        push    80                      ; maximum input length
        push    ds                      ; receives actual input length
        push    offset DGROUP:rlen
        call    DosRead

        cmp     rlen,2                  ; was anything entered?
        je      main4                   ; empty line, exit

        mov     bx,rlen                 ; remove CR-LF from input
        mov     word ptr [bx+kval-2],0

                                        ; set up for binary search
        mov     bx,fhandle              ; file handle
        mov     cx,rsize                ; record size   
        mov     dx,offset DGROUP:fbuff  ; record buffer
        mov     si,0                    ; first (left) record
        mov     di,frecs                ; last (right) record
        dec     di
        mov     bp,offset DGROUP:key    ; key structure address
        call    bsearch                 ; call search routine
        jnz     main3                   ; jump if record not found

        mov     si,offset DGROUP:msg3a  ; convert record number
        mov     cx,10                   ; to ASCII and store in output
        call    itoa

                                        ; display 'record number is nnnn'
        push    stdout                  ; standard output handle
        push    ds                      ; message address
        push    offset DGROUP:msg3
        push    msg3_len                ; message length
        push    ds                      ; receives actual bytes written
        push    offset DGROUP:wlen
        call    DosWrite                ; transfer to OS/2

        jmp     main2                   ; get another search key

main3:                                  ; display 'record not found'
        push    stdout                  ; standard output handle
        push    ds                      ; message address
        push    offset DGROUP:msg4
        push    msg4_len                ; message length
        push    ds                      ; receives actual bytes written
        push    offset DGROUP:wlen
        call    DosWrite                ; transfer to OS/2

        jmp     main2                   ; get another search key

main4:  push    1                       ; terminate all threads
        push    0                       ; return code
        call    DosExit                 ; transfer to OS/2

main    endp

_TEXT   ends

        end     main


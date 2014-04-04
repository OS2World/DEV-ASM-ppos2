        title   TYPEFILE -- demo of RLINE subroutine
        page    55,132
	.286

;  TYPEFILE.ASM -- Simple demo of RLINE subroutine (OS/2 version).  
;                  Displays text file on standard output device.
;  by Ray Duncan, (C) 1988 Ziff Davis Communications
;  Requires: RLINE.ASM, STRINGS1.ASM, ARGV.ASM, ARGC.ASM.
;
;  Build:       MASM TYPEFILE;
;               MASM RLINE;
;               MASM STRINGS1;
;               MASM ARGC;
;               MASM ARGV;
;               LINK TYPEFILE+RLINE+STRINGS1+ARGC+ARGV,,,OS2,TYPEFILE.DEF
;
;  Usage:       TYPEFILE filename.ext

cr      equ     0dh             ; ASCII carriage return
lf      equ     0ah             ; ASCII line feed
blank   equ     20h             ; ASCII space code

blksize equ     256             ; size of input file buffer     

stdin   equ     0               ; standard input handle
stdout  equ     1               ; standard output handle
stderr  equ     2               ; standard error handle

	extrn	DosClose:far	; references to API services
	extrn	DosExit:far
	extrn	DosOpen:far	
        extrn	DosWrite:far

DGROUP  group   _DATA

_TEXT   segment word public 'CODE'

        extrn   argc:near       	; external subroutines
        extrn   argv:near
        extrn   rline:near

        assume  cs:_TEXT,ds:DGROUP,es:NOTHING

main    proc    far             	; entry point from OS/2

                                	; check if filename present
        call    argc           		; count command arguments
        cmp     ax,2            	; are there 2 arguments?
        je      main1           	; yes, proceed

                                	; missing filename...
        mov     dx,offset DGROUP:msg2  	; DS:DX = error message
        mov     cx,msg2_len     	; CX = message length
        jmp     main5           	; go display it and exit

main1:                          	; get address of filename
        mov     ax,1            	; AX = argument number
        call    argv            	; returns ES:BX = address,
                                	; and AX = length

        mov     di,offset DGROUP:fname 	; copy filename to buffer
        mov     cx,ax           	; let CX = length

main2:  mov     al,es:[bx]      	; copy one byte
        mov     [di],al
        inc     bx              	; bump string pointers
        inc     di
        loop    main2           	; loop until string done
        mov     byte ptr [di],0 	; add terminal null byte

        push    ds              	; set ES = DGROUP
        pop     es
        assume  es:DGROUP

                                	; now open the file...
	push	ds			; address of filename	
        push	offset DGROUP:fname
        push	ds	        	; receives file handle
        push	offset DGROUP:fhandle
        push	ds	        	; receives DosOpen action
        push	offset DGROUP:faction
        push	0			; file allocation (N/A)
        push	0
        push	0			; attribute (N/A)
        push	1			; open but do not create
        push	40h			; read-only, deny none
	push	0			; reserved DWORD 0
        push	0	
	call	DosOpen			; transfer to OS/2
        or	ax,ax			; open successful?
        jz	main3			; yes, jump

                                	; file doesn't exist...
        mov     dx,offset DGROUP:msg1  	; DS:DX = error message
        mov     cx,msg1_len     	; CX = message length
        jmp     main5           	; go display and exit

main3:                          	; read line from file
        mov     bx,fhandle      	; BX = file handle
        mov     cx,blksize      	; CX = buffer length
        mov     dx,offset DGROUP:fbuff 	; DS:DX = buffer
        call    rline
        or      ax,ax           	; reached end of file?
        jz      main4           	; yes, exit

                                	; otherwise display line
	push	stdout			; standard output handle
        push	ds			; address of text
        push	dx
        push	ax			; length of text
        push	ds	        	; receives bytes written
        push	offset DGROUP:wlen
	call	DosWrite		; transfer to OS/2	

        jmp     main3           	; get another line

main4:                          	; success exit point
	push	fhandle			; file handle
        call	DosClose		; transfer to OS/2

        push	1			; terminate process
        push	0			; with return code = 0
        call	DosExit			; transfer to OS/2

main5:                          	; common error exit
                                	; DS:DX = message address
                                	; CX = message length
	push	stderr  		; standard error handle	
        push	ds	        	; address of error message
        push	dx
        push	cx	        	; length of error message
        push	ds	        	; receives bytes written
        push	offset DGROUP:wlen
        call	DosWrite        	; transfer to OS/2

        push	1			; terminate process
        push	1			; with return code = 1
        call	DosExit			; transfer to OS/2

main    endp

_TEXT    ends


_DATA   segment word public 'DATA'

fname   db      64 dup (0)      	; buffer for input filespec
fhandle dw      0               	; input file handle
faction	dw	0			; receives DosOpen action

fbuff   db      blksize dup (?) 	; data from input file

wlen	dw	0			; receives bytes written

msg1    db      cr,lf
        db      'typefile: file not found'
        db      cr,lf
msg1_len equ    $-msg1

msg2    db      cr,lf
        db      'typefile: missing filename'
        db      cr,lf
msg2_len equ    $-msg2

_DATA   ends    

        end     main


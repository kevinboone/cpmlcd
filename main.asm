;------------------------------------------------------------------------
;
;  main.asm 
;
;  This is a test driver for the HD44780 library in lcd.asm
;
;  Copyright (c)2023 Kevin Boone, GPL v3.0
;
;------------------------------------------------------------------------

	.Z80

	ORG    0100H

	include conio.inc
	include clargs.inc
	include lcd.inc

	JP	main

;------------------------------------------------------------------------
;  prthelp 
;  Print the help message
;------------------------------------------------------------------------
prthelp:
	PUSH	HL
	LD 	HL, us_msg
	CALL	puts
	LD 	HL, hlpmsg
	CALL	puts
	POP	HL
	RET

;------------------------------------------------------------------------
;  prtversion
;  Print the version message
;------------------------------------------------------------------------
prtversion:
	PUSH	HL
	LD 	HL, ver_msg
	CALL	puts
	POP	HL
	RET

;------------------------------------------------------------------------
;  abrtmsg: 
;  Prints the message indicated by HL, then exits. This function
;    does not return
;------------------------------------------------------------------------
abrtmsg:
	CALL	puts
	CALL	newline
	CALL	exit

;------------------------------------------------------------------------
;  abrtusmsg: 
;  Prints the message indicated by HL, then the usage message, then exits.
;  This function does not return
;------------------------------------------------------------------------
abrtusmsg:
	CALL	puts
	CALL	newline
	JP	abrtusage

;------------------------------------------------------------------------
;  trnsfm_spec 
;  In order to test the handling of special characters, this test
;    driver transforms certain backslash escapes into their ASCII
;    equivalents. The character to be tested is in A, which will be
;    changed to the new code.
;------------------------------------------------------------------------
trnsfm_spec:
	CP	'N'
	JR	NZ, .nn
	LD	A, 10
	RET
.nn:
	CP	'R'
	JR	NZ, .nr
	LD	A, 13
	RET
.nr:
	CP	'F'
	JR	NZ, .nf
	LD	A, 12
	RET
.nf:
	CP	'B'
	JR	NZ, .nb
	LD	A, 8 
	RET
.nb:
	RET

;------------------------------------------------------------------------
;  Start here 
;------------------------------------------------------------------------
main:
	; Initialize the command-line parser
	CALL	clinit
	LD	B, 0	; Arg count

	; Loop until all CL arguments have been seen
.nextarg:
	CALL	clnext
	JR	Z, .argsdone

	OR	A
	JR	Z, .notsw
	; A is non-zero, so this is a switch character 
	; The only switches we handle are /h, /v, and /s at present
	CP	'H'
	JR	NZ, .no_h
	CALL	prthelp
	JP	.done
.no_h:
	CP	'V'
	JR	NZ, .no_v
	CALL	prtversion
	JP	.done	
.no_v:
	CP	'N'
	JR	NZ, .no_n
	; We don't need to initialze the LCD driver to do this
	CALL	lcd_b0	
	JP	.done

.no_n:
	CP	'C'
	JR	NZ, .no_c
	LD	A, 1
	LD 	(cls), A
	JP	.nextarg

.no_c:
	JP	.badswitch

.notsw:
	JR	.argsdone

.argsdone:
	; Finished processing arguments. HL should point to the rest
	;  of the command line, which might just be a terminating zero

	CALL 	lcd_init	
	; TODO Perhaps don't turn backlight on unless we are doing something
	CALL	lcd_b1

	LD	A, (cls)
	CP	0
	JR	Z, .no_cls

	; If the user specified /c, clear the LCD screen
	CALL	lcd_cls

	; Set the current position to zero (which will be necessary if
	;   we aren't doing a clear-screen
.no_cls:
	LD	B, 0
	LD	C, 0
	CALL	lcd_pos

	; Loop around the command line, transforming the character if
	;   necessary, and passing it to lcd_c_at
.ch_next:
	LD	A, (HL)
	CP	0
	JR	Z, .done
	CP	'\'
	JR	NZ, .notspec
	INC	HL
	LD	A, (HL)
	CALL	trnsfm_spec
.notspec:
	CALL	lcd_c_at
	INC	HL
	JR	.ch_next

.done:
	; ...and exit cleanly
	CALL	exit

;-------------------------------------------------------------------------
; abrtusage
; print usage message and exit
;-------------------------------------------------------------------------
abrtusage:
	LD	HL, us_msg
	CALL	abrtmsg

;-------------------------------------------------------------------------
; badswitch
; print "Bad option" message and exit. 
;-------------------------------------------------------------------------
.badswitch:
	LD	HL, bs_msg
	CALL	puts
	CALL	newline
	LD	HL, us_msg
	CALL	puts
	CALL	newline
	JR	.done

;------------------------------------------------------------------------
; Data 
;------------------------------------------------------------------------
hlpmsg: 	
	db "/c clear screen"
        db 13, 10
	db "/h show help text"
        db 13, 10
	db "/n turn off backlight"
        db 13, 10
	db "/v show version"
        db 13, 10
	db 0

us_msg:
	db "Usage: lcd [/chnv] [text] "
        db 13, 10, 0

ver_msg:
	db "lcd 0.1a, copyright (c)2023 Kevin Boone, GPL v3.0"
        db 13, 10, 0

bs_msg:
	db "Bad option.", 0 

; cls is set to 1 if the user specifies /c to clear the screen
cls:	
	db 0

end 


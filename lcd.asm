;------------------------------------------------------------------------
;  lcd.asm 
;  See lcd.inc for descriptions
; 
;  Lines denoted by '####' are areas where implementation-specific 
;    configuration is likely to be required. The time delays, in 
;    particular, will benefit from being tuned to the system.
; 
;  Copyright (c)2022-3 Kevin Boone, GPL v3.0
;------------------------------------------------------------------------

 	.Z80

	global lcd_init, lcd_char, lcd_c_at, lcd_str, lcd_pos
	global lcd_b0, lcd_b1, lcd_cls, lcd_cr, lcd_lf, lcd_bs, lcd_ff


; #### Hardware interface configuration

; Z80 8-bit port to which the module is connected
PORT		equ	008H	

; Specify the width and height of the LCD module. 
LCD_COLS	equ	20
LCD_ROWS	equ	4

; Time for which the enable pin is held high to store data. 
; On an 18MHz machine, this is in units of 1.4 usec
; Of course, it will be longer on a slower CPU 
STRB_DLY	equ	250	; 350 usec 
CLS_DLY		equ	3000    ; 4 msec

; The following masks are determined by which Z80 output pins are 
;   connected to the LCD's enable (clock) an register-select lines, and
;   the backlight controller

; Backlight mask -- that is 2^pin. This is the value that must be ORed
;   to turn on the backlight 
LCD_BL_MSK	equ	001H

; Register select mask -- that is 2^pin. This is the value that must be ORed
;   to turn on the set high the register select line on the LCD 
LCD_RS_MSK 	equ 	004H 

; Enable mask -- that is 2^pin. This is the value that must be ORed
;   to turn on the set high the enable on the LCD 
LCD_EN_MSK 	equ 	008H 
; Inverse of the enable mask -- to save time we pre-compute this
LCD_DIS_MSK 	equ 	0F7H 

; No hardware-specific configuration should be required below this line,
;   but custom initialization code may be required -- see further
;   lines beginning #### 

; HD44780 command masks and variables.
; Please refer to the HD44780 data sheet for the meanings of these
;   various commands

; Clear screen command
LCD_CLR		equ	001H 

; Entry mode command
LCD_ENT_MO_SET	equ	004H 

; Set address command
LCD_SET_ADDR	equ	080H

; Constants used with entry mode command
LCD_ENT_R	equ	000H
LCD_ENT_L       equ     002H
LCD_ENT_SH_DEC  equ	000H
LCD_ENT_SH_INC  equ	001H

; Function set command
LCD_FUNC_SET	equ	020H

; Constants used with function set command
LCD_MOD_4_B	equ	000H
LCD_MOD_8_B	equ	010H
LCD_5X8		equ	000H
LCD_5X10	equ	004H
LCD_LINES_1	equ	000H
LCD_LINES_2	equ	008H

; Display control command
LCD_DISP_CTRL	equ	008H

; Constants used with display control command
LCD_NOBLINK	equ	000H
LCD_BLINK	equ	001H
LCD_CURS_OFF	equ	000H
LCD_CURS_ON	equ	002H
LCD_OFF		equ	000H
LCD_ON		equ	004H

;------------------------------------------------------------------------
;  delay 
;  Delay for a time set by the HL register. On an 18 MHz CPU, this time
;   is in units of about 1.4 usec. 
;  All registers are preserved
;------------------------------------------------------------------------
delay:
        PUSH    HL
        PUSH    AF

        ; HL value is delay * clock / t_states
        ; t_states for the main loop are 26 (4, 4, 6, 12)
        ; Z180 has 18 MHz clock, so delay is approx HL * 1.4uS 

delay_l1:
        LD      A, H            ; T=4
        OR      L               ; T=4
        DEC     HL              ; T=6
        JR      NZ, delay_l1 ;  T=12 if the condition is true

        POP     AF
        POP     HL
	RET

;------------------------------------------------------------------------
;  strb_delay 
;  Introduce a short delay for strobing the enable line
;  All registers are preserved
;------------------------------------------------------------------------
strb_delay:
	PUSH	HL
        LD      HL, STRB_DLY 
	CALL	delay
	POP	HL
        RET

;------------------------------------------------------------------------
;  cls_delay 
;  A short delay to allow the screen to clear. This time is not 
;    documented in the datasheet, so it's best to be conservative
;  All registers are preserved
;------------------------------------------------------------------------
cls_delay:
	PUSH	HL
        LD      HL, CLS_DLY 
	CALL	delay
	POP	HL
        RET

;------------------------------------------------------------------------
; out_port
; Write A to the configured 8-bit port. Registers preserved
;------------------------------------------------------------------------
out_port:
	; TODO TODO TODO
	OUT	(PORT), A
	RET

;------------------------------------------------------------------------
; write_byte 
; Write a byte to the LCD, as two four-bit operations. We must strobe
;   the enable pin after each 4-bit write. The backlight control line
;   does not go to the LCD, but we must maintain it whilst updating
;   the LCD, so it doesn't flicker.
; AF register modified
;------------------------------------------------------------------------
send_4bits:
        ; Set data without enable
	PUSH	BC
	LD	B, A
	LD	A, (bl)
	OR	B
	AND	LCD_DIS_MSK
	CALL	out_port
        ; Set data with enable
	CALL	strb_delay
	OR	LCD_EN_MSK
	CALL	out_port
        ; Set data without enable
	CALL	strb_delay
	AND	LCD_DIS_MSK
	CALL	out_port
	CALL	strb_delay
	POP	BC
	RET

;------------------------------------------------------------------------
; send_byte_cmd 
; Sends a command; that is, a byte with the register select line low
; AF register modified
;------------------------------------------------------------------------
send_byte_cmd:
	PUSH	AF
	AND	0F0H
	CALL    send_4bits
	POP	AF
	SLA	A
	SLA	A
	SLA	A
	SLA	A
	AND	0F0H
	CALL	send_4bits
	RET

;------------------------------------------------------------------------
; send_byte_data
; Sends a character; that is, a byte with the register select line high 
; AF register modified
;------------------------------------------------------------------------
send_byte_data:
	PUSH	AF
	AND	0F0H
	OR	LCD_RS_MSK
	CALL    send_4bits
	POP	AF
	SLA	A
	SLA	A
	SLA	A
	SLA	A
	AND	0F0H
	OR	LCD_RS_MSK
	CALL	send_4bits
	RET


;------------------------------------------------------------------------
; lcd_advance
; Advance the display cursor one place after writing a character. 
; Move to the next line if the current position is > LCD_COLS
; AF register modified
;------------------------------------------------------------------------
lcd_advance:
	LD	A, (col)
	INC	A
	CP	LCD_COLS
	JR	NC, .wrap
	LD	(col), A
	RET
.wrap:
	CALL	lcd_cr	
	CALL	lcd_lf	
	RET

;------------------------------------------------------------------------
; lcd_char
; Write character in AF at LCD's idea of current position
; AF register modified
;------------------------------------------------------------------------
lcd_char:
	CALL	send_byte_data
	RET

;------------------------------------------------------------------------
; lcd_align
; Sets the LCD module's cursor position to match the stored values of
;   (row) and (col). This should be called after any change in these
;   values.
; This alignment is complicated by the fact that the rows of the 
;   LCD module are non-linear. Row 0, for example, is 64 character cells,
;   whatever the width of the module. Row 0 wraps around onto row 2, not
;   row 1. 
; All registers preserved
;------------------------------------------------------------------------
lcd_align:
	PUSH	AF
	PUSH	DE
	PUSH	BC
	PUSH	HL
	LD	A, (row)
	LD	D, 0
	LD	E, A
	LD	A, (col)
	LD	C, A
        LD	HL, offsets
	ADD	HL, DE
	LD	A, (HL)
        ; Row offset now in A
        ADD	A, C 
	OR	lcd_set_addr	
        ; Row+col offset now in A
	CALL 	send_byte_cmd
	POP	HL
	POP	BC
	POP 	DE	
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_cr
; Force a carriage return
;------------------------------------------------------------------------
lcd_cr:
	PUSH 	AF
	LD	A, 0
	LD	(col), A
	CALL	lcd_align
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_lf
; Force a line feed 
;------------------------------------------------------------------------
lcd_lf:
	PUSH 	AF
	LD	A, (row) 
	INC	A
	LD	(row), A
	; At this point we should check that the output hasn't
	;   gone below the bottom row, and scroll up.
	CALL	lcd_align
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_ff
; Force a form feed, i.e., clear the display 
;------------------------------------------------------------------------
lcd_ff:
	CALL	lcd_cls
	RET

;------------------------------------------------------------------------
; lcd_bs
; Force a non-destructive backspace 
;------------------------------------------------------------------------
lcd_bs:
	PUSH	AF
	LD	A, (col)
	SUB	1	
	LD	(col), A
	JR	NC, .bsdone	
	; col is now negative
	LD	A, LCD_COLS
	DEC	A	
	LD	(col), A
	LD	A, (row)
 	SUB	1	
	LD	(row), A
	JR	NC, .bsdone
	; What do we do when we backspace off the top of the screen?
	LD	A, 0
	LD	(col), A
	LD	(row), A
	
.bsdone:
	CALL	lcd_align
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_spec
; Process a special ASCII character. If the character was processed, 
;   the zero flag is set on exit. 
;------------------------------------------------------------------------
lcd_spec:
	CP	10
	JR	NZ, .n10
	CALL	lcd_cr
	RET
.n10:
	CP	13
	JR	NZ, .n13
	CALL	lcd_lf
	RET
.n13:
	CP	12
	JR	NZ, .n12
	CALL	lcd_ff
	RET
.n12:
	CP 	8	
	JR	NZ, .n8
	CALL	lcd_bs
	RET

.n8:
	; zero flag will be clear here because of the comparison
	RET

;------------------------------------------------------------------------
; lcd_char_at
; Display the character at the current position, and advance the cursor
;------------------------------------------------------------------------
lcd_c_at:
	PUSH	AF
	CALL	lcd_spec
	JR	Z, .didspec
	CALL	lcd_align
	CALL	lcd_char
	CALL	lcd_advance
.didspec:
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_pos
; Update the LCD's and this module's idea of the current position
; B = row, C = col; all registers preserved 
;------------------------------------------------------------------------
lcd_pos:
	PUSH	AF
	LD	A, B
	LD	(row), A
	LD	A, C
	LD	(col), A
	CALL	lcd_align
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_str
; Write the zero-terminated string pointed to by HL
;------------------------------------------------------------------------
lcd_str:
	PUSH	AF	
	PUSH	HL

.str_next:
	LD	A, (HL)
	CP	0
	JR	Z, .str_done
	CALL	lcd_c_at
	INC	HL
	JR	.str_next

.str_done:
	POP	HL
	POP 	AF	
	RET

;------------------------------------------------------------------------
; lcd_l0
; Backlight off
;------------------------------------------------------------------------
lcd_b0:
	PUSH	AF
	LD	A, 0 
	OUT	(PORT), A
	LD	(bl), A
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_b1
; Backlight on
;------------------------------------------------------------------------
lcd_b1:
	PUSH	AF
	LD	A, LCD_BL_MSK
	OUT	(PORT), A
	LD	(bl), A
	POP	AF
	RET

;------------------------------------------------------------------------
; lcd_cls
; clear display 
;------------------------------------------------------------------------
lcd_cls:
	PUSH	AF
	LD 	A, LCD_CLR 
	CALL	send_byte_cmd
	LD	A, 0
	LD	(row), A
	LD	(col), A
	POP	AF
	CALL	cls_delay
	RET

;------------------------------------------------------------------------
; lcd_init 
; Initialize the display
; All registers preserved
;------------------------------------------------------------------------
lcd_init:
	; #### Insert custom port initialization here

	PUSH	AF
 	; Send the arcane cmd sequence that puts the display into
	;   4-bit receptivity
	LD 	A, 3
	CALL	send_byte_cmd
	LD 	A, 3
	CALL	send_byte_cmd
	LD 	A, 3
	CALL	send_byte_cmd
	LD 	A, 2
	CALL	send_byte_cmd

	; Set left-to-right
	; #### Modify this section if your want the display to scroll
	; ####   horizintally, rather than to move the cursor
	LD	A, LCD_ENT_MO_SET
	OR	LCD_ENT_L	
	OR	LCD_ENT_SH_DEC 
	CALL	send_byte_cmd

	; Set 4-bit, two lines, 5x8 characters
	; Note that 'two line' mode works with 4-line displays
	; #### Modify this section if you have a one-line display
	LD	A, LCD_FUNC_SET
	OR	LCD_MOD_4_B
	OR	LCD_LINES_2
	OR	LCD_5X8
	CALL	send_byte_cmd

	; Turn display on
        LD 	A, LCD_DISP_CTRL
	OR	LCD_ON
	; #### Modify these two lines if you don't want a cursor, or
	; ####   don't want it blinking
	OR	LCD_CURS_ON
	OR	LCD_NOBLINK
	CALL	send_byte_cmd

	POP	AF
	RET


; Offset table -- the position in the LCD's memory where each row starts
offsets: 	db 0, 64, LCD_COLS, LCD_COLS + 64 
; Current row
row:		db 0
; Current column
col:		db 0
; Stored backlight mask, modified by lcd_b0 and lcd_b1
bl:		db 0

end


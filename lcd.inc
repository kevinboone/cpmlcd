;------------------------------------------------------------------------
;  lcd.inc
;  
;  A driver library for an HD44780 LCD module, connected in 4-bit
;    mode
; 
;  Copyright (c)2021-3 Kevin Boone, GPL v3.0
;------------------------------------------------------------------------

	.Z80

;------------------------------------------------------------------------
;  lcd_init
;  Initialize the display. Does _not_ turn on the backlight.  
;------------------------------------------------------------------------
	external lcd_init 

;------------------------------------------------------------------------
;  lcd_char 
;  Writes a character to the display without regard for the current 
;    position or handling of special characters
;  All registers except AF preserved 
;------------------------------------------------------------------------
	external lcd_char

;------------------------------------------------------------------------
;  lcd_char_at
;  Writes the character at the current position, and then advances the
;    text position. If the text entry reaches the end of line, wrap 
;    around to the next line. 
;  The following control characters are recognized -- 08: non-destructive
;    backspace; 10: line feed; 12: form feed; 13: carriage return. All
;    other characters are passed through unchanged to the LCD. The
;    interpretation of non-ASCII characters is vendor-specific.
;  All registers preserved
;------------------------------------------------------------------------
	external lcd_c_at

;------------------------------------------------------------------------
;  lcd_pos
;  Set the current text position to row=B, col=C. This routine sets the
;    modules internal idea of position, and also the LCD module's 
;    current position. No checks are made that the C and C values are
;    in the right range.
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_pos

;------------------------------------------------------------------------
;  lcd_b0
;  Turn off the backlight, and remember it should be off.
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_b0

;------------------------------------------------------------------------
;  lcd_b1
;  Turn on the backlight, and remember it should be on.
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_b1


;------------------------------------------------------------------------
;  lcd_str
;  Outputs the zero-terminated string who address is in HL to the LCD.
;  This essentially just calls lcd_c_at in a loop, so the same control
;    characters are recognized. 
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_str

;------------------------------------------------------------------------
;  lcd_cls
;  Clear the display and home the cursor  
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_cls
  
;------------------------------------------------------------------------
;  lcd_cr
;  Display a carriage return (cursor to start of line)
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_cr

;------------------------------------------------------------------------
;  lcd_lf
;  Display a line feed (cursor down one line)
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_lf

;------------------------------------------------------------------------
;  lcd_ff
;  Display a form feed (clear the display)
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_ff

;------------------------------------------------------------------------
;  lcd_bs
;  Display a non-destructive backspace. The cursor is moved, but no
;    characters are deleted. You can get a destructive backspace by
;    outputting backspace-space-backspace.
;  All registers preserved.
;------------------------------------------------------------------------
	external lcd_bs



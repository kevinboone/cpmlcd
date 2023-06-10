
# Set the path to the CPM emulator. 
# Obtain it from here: https://github.com/jhallen/cpm
CPM=cpm

# Define the assembler and linker. Get Macro80 and Link80 from here:
# http://www.retroarchive.org/cpm/lang/m80.com
# http://www.retroarchive.org/cpm/lang/l80.com
MACRO80=m80
LINK80=l80

NAME=lcd
TARGET=lcd.com

all: $(TARGET)

main.rel: main.asm conio.inc clargs.inc lcd.inc
	$(CPM) $(MACRO80) =main.asm

conio.rel: conio.asm bdos.inc
	$(CPM) $(MACRO80) =conio.asm

clargs.rel: clargs.asm mem.inc
	$(CPM) $(MACRO80) =clargs.asm

lcd.rel: lcd.asm lcd.inc
	$(CPM) $(MACRO80) =lcd.asm

mem.rel: mem.asm mem.inc
	$(CPM) $(MACRO80) =mem.asm

$(TARGET): conio.rel main.rel  clargs.rel mem.rel lcd.rel
	$(CPM) $(LINK80) main,conio,clargs,mem,lcd,$(NAME)/n/e

clean:
	rm -f $(TARGET) *.rel


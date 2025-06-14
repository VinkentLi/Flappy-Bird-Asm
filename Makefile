all: main.o
	gcc -o main main.o -nostdlib -lkernel32 -lsdl2 -lmsvcrt

main.o: main.asm
	nasm -f win64 -o main.o main.asm

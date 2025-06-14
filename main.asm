bits 64
default rel

extern SDL_Init
extern SDL_GetError
extern SDL_CreateWindow
extern SDL_CreateRenderer
extern SDL_RenderClear
extern SDL_RenderPresent
extern SDL_SetRenderDrawColor
extern SDL_RenderFillRect
extern SDL_PollEvent
extern SDL_Delay
extern SDL_Quit
extern fprintf
extern __acrt_iob_func
extern time
extern srand
extern rand
extern ExitProcess

section .text
global main

%define SDL_INIT_VIDEO 0x20
%define SDL_WINDOW_SHOWN 0x00000004
%define SDL_WINDOWPOS_CENTERED 0x2FFF0000
%define SDL_RENDERER_ACCELERATED 0x00000002
%define SDL_QUIT 0x100
%define SDL_MOUSEBUTTONDOWN 0x401
%define GRAVITY 1

main:
    sub rsp, 56 ; shadow space for functions
    ; init SDL
    mov ecx, SDL_INIT_VIDEO
    call SDL_Init
    cmp eax, 0 ; check if successful
    jnz failure ; if it fails, goto failure
    ; create window
    lea rcx, [title]
    mov edx, SDL_WINDOWPOS_CENTERED ; centered x
    mov r8d, SDL_WINDOWPOS_CENTERED ; centered y
    mov r9d, 600 ; width
    mov dword [rsp+32], 500 ; height
    mov dword [rsp+40], SDL_WINDOW_SHOWN ; flags
    call SDL_CreateWindow
    cmp rax, 0 ; check if null
    jz failure ; if it is, goto failure
    mov r12, rax ; store window in r12
    ; create renderer
    mov rcx, r12 ; window param
    mov edx, -1 ; index
    mov r8d, SDL_RENDERER_ACCELERATED ; flags
    call SDL_CreateRenderer
    test rax, rax ; test if renderer was made
    jz failure ; otherwise goto failure
    mov r13, rax ; store renderer in r13
    mov r14b, 1 ; store game_running
    ; init random
    mov rcx, 0 
    call time 
    mov rcx, rax
    call srand
    ; init player
    mov dword [player_y], 460 ; player_y will be halved
    mov dword [player_y_velo], 0
    mov byte [player_dead], 0
    ; init pipes
    mov dword [pipe1_x], 600
    mov dword [pipe2_x], 900
    call rand
    shr eax, 8 ; it's a range from 1-32767 divided by 128
    sub eax, 314
    mov dword [pipe1_y], eax
    call rand
    shr eax, 8
    sub eax, 314
    mov dword [pipe2_y], eax
main_loop:
    call handle_events
    call update
    call render
    mov ecx, 17
    call SDL_Delay ; delay for 17 ms for 60fps
    test r14b, r14b ; check if game is still running
    jnz main_loop
    ; quit
    call SDL_Quit
    mov eax, 0 ; exit code 0
    call ExitProcess ; quit

handle_events:
    sub rsp, 96 ; reserve space for shadow space and SDL_Event
poll_event:
    lea rcx, [rsp+32] ; pass SDL_Event pointer
    call SDL_PollEvent
    test eax, eax ; check if there is an event
    jz quit_polling ; if SDL_PollEvent returned false, quit
    mov eax, dword [rsp+32] ; move event.type to eax
    cmp eax, SDL_QUIT
    je quit ; don't do anything if not quitting
    ; check mouse inputs
    cmp eax, SDL_MOUSEBUTTONDOWN
    jne poll_event
    ; if player is dead, revive player
    mov al, [player_dead]
    test al, al
    jnz revive_player
    ; otherwise, jump
    mov dword [player_y_velo], -16
    jmp poll_event
revive_player:
    mov byte [player_dead], 0
    mov dword [player_y], 460
    mov dword [player_y_velo], 0
    ; reset pipes
    mov dword [pipe1_x], 600
    mov dword [pipe2_x], 900
    call rand
    shr eax, 6 
    sub eax, 314
    mov dword [pipe1_y], eax
    call rand
    shr eax, 6
    sub eax, 314
    mov dword [pipe2_y], eax
    jmp poll_event
quit:
    mov r14b, 0 ; set game_running to false
    jmp quit_polling
quit_polling:
    add rsp, 96 ; reset stack
    ret

update:
    mov al, [player_dead]
    test al, al ; see if player dead
    jz update_game ; if not, update y
    ret ; otherwise do nothing
update_game:
    ; move pipes
    mov eax, [pipe1_x]
    sub eax, 2
    mov [pipe1_x], eax
    mov eax, [pipe2_x]
    sub eax, 2
    mov [pipe2_x], eax
    ; if pipe1 goes out of bounds, wrap around
    cmp dword [pipe1_x], -100
    jg try_move_pipe2
    mov dword [pipe1_x], 600
    call rand
    shr eax, 8
    sub eax, 314
    mov dword [pipe1_y], eax
try_move_pipe2:
    cmp dword [pipe2_x], -100
    jg move_player
    mov dword [pipe2_x], 600
    call rand
    shr eax, 8
    sub eax, 314
    mov dword [pipe2_y], eax
move_player:
    mov eax, [player_y_velo]
    add eax, GRAVITY
    mov [player_y_velo], eax
    mov eax, [player_y]
    add eax, [player_y_velo]
    mov [player_y], eax
    ; if player goes out of bounds, kill
    cmp eax, 0
    jle kill_player
    cmp eax, 920
    jge kill_player
pipe1_collisions:
    cmp dword [pipe1_x], 320
    jge pipe2_collisions
    cmp dword [pipe1_x], 180
    jle pipe2_collisions
    mov ebx, [pipe1_y]
    add ebx, 500
    shl ebx, 1 ; double y to match player
    cmp eax, ebx
    jl kill_player ; kill player if touching upper pipe
    add ebx, 220
    cmp eax, ebx
    jg kill_player ; kill player if touching lower pipe
pipe2_collisions:
    cmp dword [pipe2_x], 320
    jge done_with_collisions
    cmp dword [pipe2_x], 180
    jle done_with_collisions
    mov ebx, [pipe2_y]
    add ebx, 500
    shl ebx, 1 ; double y to match player
    cmp eax, ebx
    jl kill_player ; kill player if touching upper pipe
    add ebx, 220
    cmp eax, ebx
    jg kill_player ; kill player if touching lower pipe
done_with_collisions:
    ret
kill_player:
    mov byte [player_dead], 1
    ret

render:
    sub rsp, 56 ; reserve space for shadow space and SDL_Rect (reused between player and pipes)
    ; set color to black
    mov rcx, r13 ; renderer param
    mov dl, 0x00 ; red
    mov r8b, 0xaf ; green
    mov r9b, 0xff ; blue
    mov byte [rsp+32], 0xff ; alpha
    mov rcx, r13
    call SDL_SetRenderDrawColor
    call SDL_RenderClear
    ; set color to green
    mov rcx, r13 ; renderer param
    mov dl, 0x00 ; red
    mov r8b, 0xff ; green
    mov r9b, 0x00 ; blue
    mov byte [rsp+32], 0xff ; alpha
    call SDL_SetRenderDrawColor
    ; render pipe1
    mov eax, [pipe1_x]
    mov ebx, [pipe1_y]
    mov dword [rsp+36], eax
    mov dword [rsp+40], ebx
    mov dword [rsp+44], 100
    mov dword [rsp+48], 500
    mov rcx, r13
    lea rdx, [rsp+36]
    call SDL_RenderFillRect
    add ebx, 650
    mov dword [rsp+40], ebx
    mov rcx, r13
    lea rdx, [rsp+36]
    call SDL_RenderFillRect
    ; render pipe2
    mov eax, [pipe2_x]
    mov ebx, [pipe2_y]
    mov dword [rsp+36], eax
    mov dword [rsp+40], ebx
    mov rcx, r13
    lea rdx, [rsp+36]
    call SDL_RenderFillRect
    add ebx, 650
    mov dword [rsp+40], ebx
    mov rcx, r13
    lea rdx, [rsp+36]
    call SDL_RenderFillRect
    ; set color to yellow
    mov rcx, r13 ; renderer param
    mov dl, 0xff ; red
    mov r8b, 0xff ; green
    mov r9b, 0x00 ; blue
    mov byte [rsp+32], 0xff ; alpha
    call SDL_SetRenderDrawColor
    ; draw rect
    mov dword [rsp+36], 280
    mov eax, [player_y]
    sar eax, 1 ; halve player_y, this way calculations can be more precise without floating point numbers
    mov dword [rsp+40], eax
    mov dword [rsp+44], 40
    mov dword [rsp+48], 40
    mov rcx, r13
    lea rdx, [rsp+36]
    call SDL_RenderFillRect
    mov rcx, r13
    call SDL_RenderPresent
    add rsp, 56 ; reset stack
    ret

failure:
    call SDL_GetError
    mov r8, rax ; store error
    mov rcx, 2
    call __acrt_iob_func
    mov rcx, rax ; get stderr and store it
    lea rdx, [errmsg]
    call fprintf
    mov ecx, 1 ; exit code 1
    call ExitProcess ; quit

segment .data
    title db "Flappy Bird", 0
    errmsg db "SDL Error: %s", 10, 0 

segment .bss
    player_y resd 1
    player_y_velo resd 1
    pipe1_x resd 1
    pipe1_y resd 1
    pipe2_x resd 1
    pipe2_y resd 1 
    player_dead resb 1

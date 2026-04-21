; ============================================================================
; Hollow Knight Assembly Demo — Main Entry Point (Windows / Win32)
; Window creation, game loop, input via WndProc, framebuffer blit
; ============================================================================

%include "constants.inc"

; ---- Win32 constants ----
%define WM_DESTROY      0x0002
%define WM_CLOSE        0x0010
%define WM_QUIT         0x0012
%define WM_ERASEBKGND   0x0014
%define WM_KEYDOWN      0x0100
%define WM_KEYUP        0x0101
%define WM_LBUTTONDOWN  0x0201
%define WM_LBUTTONUP    0x0202
%define WM_RBUTTONDOWN  0x0204
%define WM_RBUTTONUP    0x0205

%define CS_HREDRAW      0x0002
%define CS_VREDRAW      0x0001
%define WS_OVERLAPPEDWINDOW 0x00CF0000
%define WS_VISIBLE      0x10000000
%define CW_USEDEFAULT   0x80000000
%define PM_REMOVE       0x0001
%define SW_SHOW         5

%define VK_ESCAPE   0x1B
%define VK_SPACE    0x20
%define VK_A        0x41
%define VK_D        0x44
%define VK_Q        0x51
%define VK_S        0x53
%define VK_W        0x57

; WNDCLASSEXA offsets (x64)
%define WC_CBSIZE       0
%define WC_STYLE        4
%define WC_WNDPROC      8
%define WC_CLSEXTRA    16
%define WC_WNDEXTRA    20
%define WC_HINSTANCE   24
%define WC_HICON       32
%define WC_HCURSOR     40
%define WC_HBRBACKGROUND 48
%define WC_MENUNAME    56
%define WC_CLASSNAME   64
%define WC_HICONSM     72
%define WC_SIZE        80

; MSG offsets
%define MSG_MESSAGE     8
%define MSG_SIZE       48

; ---- External Win32 API ----
extern GetModuleHandleA
extern RegisterClassExA
extern CreateWindowExA
extern AdjustWindowRect
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern PostQuitMessage
extern DefWindowProcA
extern LoadCursorA
extern GetDC
extern ReleaseDC
extern SetDIBitsToDevice
extern QueryPerformanceFrequency
extern QueryPerformanceCounter
extern Sleep
extern ExitProcess
extern calloc

; ---- Game module functions ----
extern render_frame
extern init_level
extern init_enemies
extern update_player
extern update_enemies
extern check_enemy_collisions
extern init_sprites

; ---- Globals ----
global main
global framebuffer
global game_running, frame_count, game_state
global init_game_state

global key_left, key_right, key_up, key_down
global key_jump, key_attack, key_dash
global key_jump_pressed, key_attack_pressed, key_dash_pressed

global player_x, player_y, player_vx, player_vy
global player_hp, player_facing, player_on_ground
global player_state, player_anim_frame, player_anim_timer
global player_invuln_timer
global player_dash_timer, player_dash_cooldown
global player_slash_active, player_slash_timer, player_slash_cooldown
global player_slash_x, player_slash_y

global enemies, num_enemies

section .data
    class_name:     db "HollowKnightClass", 0
    window_title:   db "Hollow Knight - Assembly Demo", 0

    align 4
    bmi:
        dd 40               ; biSize
        dd WINDOW_W          ; biWidth = 640
        dd -WINDOW_H         ; biHeight = -480 (top-down DIB)
        dw 1                 ; biPlanes
        dw 32                ; biBitCount
        dd 0                 ; biCompression = BI_RGB
        dd 0                 ; biSizeImage
        dd 0                 ; biXPelsPerMeter
        dd 0                 ; biYPelsPerMeter
        dd 0                 ; biClrUsed
        dd 0                 ; biClrImportant

section .bss
    hwnd_main:      resq 1
    hinstance:      resq 1
    framebuffer:    resq 1

    wndclass:       resb WC_SIZE
    msg_buf:        resb MSG_SIZE
    adj_rect:       resd 4

    perf_freq:      resq 1
    perf_start:     resq 1
    perf_end:       resq 1

    ; Input state
    key_left:       resb 1
    key_right:      resb 1
    key_up:         resb 1
    key_down:       resb 1
    key_jump:       resb 1
    key_attack:     resb 1
    key_dash:       resb 1
    key_jump_pressed:   resb 1
    key_attack_pressed: resb 1
    key_dash_pressed:   resb 1

    ; Player state
    player_x:       resd 1
    player_y:       resd 1
    player_vx:      resd 1
    player_vy:      resd 1
    player_hp:      resd 1
    player_facing:  resd 1
    player_on_ground: resd 1
    player_state:   resd 1
    player_anim_frame: resd 1
    player_anim_timer: resd 1
    player_invuln_timer: resd 1
    player_dash_timer:   resd 1
    player_dash_cooldown: resd 1
    player_slash_active:  resd 1
    player_slash_timer:   resd 1
    player_slash_cooldown: resd 1
    player_slash_x: resd 1
    player_slash_y: resd 1

    ; Enemy array
    enemies:        resb ENEMY_STRUCT_SIZE * MAX_ENEMIES
    num_enemies:    resd 1

    ; Game state
    game_running:   resd 1
    game_state:     resd 1
    frame_count:    resq 1

section .text

; ============================================================================
; WndProc — Window procedure (Microsoft x64 callback)
; rcx=hwnd, rdx=uMsg, r8=wParam, r9=lParam
; ============================================================================
WndProc:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    push rsi
    push r12
    push r13
    sub rsp, 40

    mov rbx, rcx
    mov r12d, edx
    mov r13, r8
    mov rdi, r9

    cmp r12d, WM_KEYDOWN
    je .keydown
    cmp r12d, WM_KEYUP
    je .keyup
    cmp r12d, WM_LBUTTONDOWN
    je .lbdown
    cmp r12d, WM_LBUTTONUP
    je .lbup
    cmp r12d, WM_RBUTTONDOWN
    je .rbdown
    cmp r12d, WM_RBUTTONUP
    je .rbup
    cmp r12d, WM_CLOSE
    je .close
    cmp r12d, WM_DESTROY
    je .destroy
    cmp r12d, WM_ERASEBKGND
    je .erasebg
    jmp .defproc

; ---- Key down ----
.keydown:
    cmp r13d, VK_A
    je .kd_left
    cmp r13d, VK_D
    je .kd_right
    cmp r13d, VK_W
    je .kd_up
    cmp r13d, VK_S
    je .kd_down
    cmp r13d, VK_SPACE
    je .kd_jump
    cmp r13d, VK_ESCAPE
    je .kd_quit
    cmp r13d, VK_Q
    je .kd_quit
    jmp .defproc

.kd_left:
    mov byte [rel key_left], 1
    jmp .ret_zero
.kd_right:
    mov byte [rel key_right], 1
    jmp .ret_zero
.kd_up:
    mov byte [rel key_up], 1
    jmp .ret_zero
.kd_down:
    mov byte [rel key_down], 1
    jmp .ret_zero
.kd_jump:
    cmp byte [rel key_jump], 0
    jne .ret_zero
    mov byte [rel key_jump], 1
    mov byte [rel key_jump_pressed], 1
    jmp .ret_zero
.kd_quit:
    mov dword [rel game_running], 0
    jmp .ret_zero

; ---- Key up ----
.keyup:
    cmp r13d, VK_A
    je .ku_left
    cmp r13d, VK_D
    je .ku_right
    cmp r13d, VK_W
    je .ku_up
    cmp r13d, VK_S
    je .ku_down
    cmp r13d, VK_SPACE
    je .ku_jump
    jmp .defproc

.ku_left:
    mov byte [rel key_left], 0
    jmp .ret_zero
.ku_right:
    mov byte [rel key_right], 0
    jmp .ret_zero
.ku_up:
    mov byte [rel key_up], 0
    jmp .ret_zero
.ku_down:
    mov byte [rel key_down], 0
    jmp .ret_zero
.ku_jump:
    mov byte [rel key_jump], 0
    jmp .ret_zero

; ---- Mouse buttons ----
.lbdown:
    cmp byte [rel key_attack], 0
    jne .ret_zero
    mov byte [rel key_attack], 1
    mov byte [rel key_attack_pressed], 1
    jmp .ret_zero
.lbup:
    mov byte [rel key_attack], 0
    jmp .ret_zero
.rbdown:
    cmp byte [rel key_dash], 0
    jne .ret_zero
    mov byte [rel key_dash], 1
    mov byte [rel key_dash_pressed], 1
    jmp .ret_zero
.rbup:
    mov byte [rel key_dash], 0
    jmp .ret_zero

; ---- Window close / destroy ----
.close:
    mov dword [rel game_running], 0
    jmp .defproc

.destroy:
    xor ecx, ecx
    call PostQuitMessage
    jmp .ret_zero

.erasebg:
    mov eax, 1
    jmp .epilog

.defproc:
    mov rcx, rbx
    mov edx, r12d
    mov r8, r13
    mov r9, rdi
    call DefWindowProcA
    jmp .epilog

.ret_zero:
    xor eax, eax

.epilog:
    add rsp, 40
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret


; ============================================================================
; main — program entry point
; ============================================================================
main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi
    push rsi
    sub rsp, 104

    ; ---- GetModuleHandleA(NULL) ----
    xor ecx, ecx
    call GetModuleHandleA
    mov [rel hinstance], rax
    mov rbx, rax

    ; ---- LoadCursorA(NULL, IDC_ARROW=32512) ----
    xor ecx, ecx
    mov edx, 32512
    call LoadCursorA
    mov r12, rax

    ; ---- Fill WNDCLASSEXA ----
    lea rdi, [rel wndclass]
    mov ecx, WC_SIZE / 8
    xor eax, eax
    rep stosq

    lea r13, [rel wndclass]
    mov dword [r13 + WC_CBSIZE], WC_SIZE
    mov dword [r13 + WC_STYLE], CS_HREDRAW | CS_VREDRAW
    lea rax, [rel WndProc]
    mov [r13 + WC_WNDPROC], rax
    mov [r13 + WC_HINSTANCE], rbx
    mov [r13 + WC_HCURSOR], r12
    lea rax, [rel class_name]
    mov [r13 + WC_CLASSNAME], rax

    ; ---- RegisterClassExA ----
    mov rcx, r13
    call RegisterClassExA
    test ax, ax
    jz .init_fail

    ; ---- AdjustWindowRect for correct 640x480 client area ----
    lea r13, [rel adj_rect]
    mov dword [r13], 0
    mov dword [r13+4], 0
    mov dword [r13+8], WINDOW_W
    mov dword [r13+12], WINDOW_H

    mov rcx, r13
    mov edx, WS_OVERLAPPEDWINDOW
    xor r8d, r8d
    call AdjustWindowRect

    mov eax, [rel adj_rect + 8]
    sub eax, [rel adj_rect]
    mov r14d, eax
    mov eax, [rel adj_rect + 12]
    sub eax, [rel adj_rect + 4]
    mov r15d, eax

    ; ---- CreateWindowExA (12 args: 4 reg + 8 stack) ----
    xor ecx, ecx
    lea rdx, [rel class_name]
    lea r8, [rel window_title]
    mov r9d, WS_OVERLAPPEDWINDOW | WS_VISIBLE
    mov dword [rsp+32], CW_USEDEFAULT
    mov dword [rsp+36], -1
    mov dword [rsp+40], CW_USEDEFAULT
    mov dword [rsp+44], -1
    movsxd rax, r14d
    mov [rsp+48], rax
    movsxd rax, r15d
    mov [rsp+56], rax
    mov qword [rsp+64], 0
    mov qword [rsp+72], 0
    mov rax, [rel hinstance]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExA
    test rax, rax
    jz .init_fail
    mov [rel hwnd_main], rax

    ; ---- ShowWindow + UpdateWindow ----
    mov rcx, [rel hwnd_main]
    mov edx, SW_SHOW
    call ShowWindow
    mov rcx, [rel hwnd_main]
    call UpdateWindow

    ; ---- QueryPerformanceFrequency ----
    lea rcx, [rel perf_freq]
    call QueryPerformanceFrequency

    ; ---- Allocate framebuffer: calloc(W*H, 4) ----
    mov ecx, WINDOW_W * WINDOW_H
    mov edx, BPP
    call calloc
    test rax, rax
    jz .init_fail
    mov [rel framebuffer], rax

    ; ---- Initialize game ----
    call init_game_state
    call init_sprites
    call init_level
    call init_enemies

    mov dword [rel game_running], 1
    mov dword [rel game_state], 1

    ; ============================================================
    ; MAIN GAME LOOP
    ; ============================================================
.game_loop:
    lea rcx, [rel perf_start]
    call QueryPerformanceCounter

    mov byte [rel key_jump_pressed], 0
    mov byte [rel key_attack_pressed], 0
    mov byte [rel key_dash_pressed], 0

    ; ---- Process all pending messages ----
.msg_loop:
    lea rcx, [rel msg_buf]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword [rsp+32], PM_REMOVE
    call PeekMessageA
    test eax, eax
    jz .msg_done

    cmp dword [rel msg_buf + MSG_MESSAGE], WM_QUIT
    je .game_exit

    lea rcx, [rel msg_buf]
    call TranslateMessage
    lea rcx, [rel msg_buf]
    call DispatchMessageA
    jmp .msg_loop

.msg_done:
    cmp dword [rel game_running], 0
    je .game_exit

    ; ---- Update game logic ----
    call update_player
    call update_enemies
    call check_enemy_collisions

    ; ---- Render frame + blit to window ----
    call render_frame
    call blit_to_window

    ; ---- Frame timing ----
    call frame_delay

    inc qword [rel frame_count]
    jmp .game_loop

    ; ============================================================
    ; CLEANUP & EXIT
    ; ============================================================
.game_exit:
    xor eax, eax
    add rsp, 104
    pop rsi
    pop rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.init_fail:
    mov ecx, 1
    call ExitProcess


; ============================================================================
; init_game_state — set player and game to initial values
; ============================================================================
init_game_state:
    mov dword [rel player_x], 40 * 256
    mov dword [rel player_y], 180 * 256
    mov dword [rel player_vx], 0
    mov dword [rel player_vy], 0
    mov dword [rel player_hp], MAX_HP
    mov dword [rel player_facing], 0
    mov dword [rel player_on_ground], 0
    mov dword [rel player_state], STATE_IDLE
    mov dword [rel player_anim_frame], 0
    mov dword [rel player_anim_timer], 0
    mov dword [rel player_invuln_timer], 0
    mov dword [rel player_dash_timer], 0
    mov dword [rel player_dash_cooldown], 0
    mov dword [rel player_slash_active], 0
    mov dword [rel player_slash_timer], 0
    mov dword [rel player_slash_cooldown], 0
    mov qword [rel frame_count], 0
    mov byte [rel key_left], 0
    mov byte [rel key_right], 0
    mov byte [rel key_up], 0
    mov byte [rel key_down], 0
    mov byte [rel key_jump], 0
    mov byte [rel key_attack], 0
    mov byte [rel key_dash], 0
    ret


; ============================================================================
; blit_to_window — copy framebuffer to window via SetDIBitsToDevice
; ============================================================================
blit_to_window:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 104

    ; GetDC(hwnd)
    mov rcx, [rel hwnd_main]
    call GetDC
    mov rbx, rax

    ; SetDIBitsToDevice(hdc, 0, 0, W, H, 0, 0, 0, H, bits, bmi, 0)
    mov rcx, rbx
    xor edx, edx
    xor r8d, r8d
    mov r9d, WINDOW_W
    mov qword [rsp+32], WINDOW_H
    mov qword [rsp+40], 0
    mov qword [rsp+48], 0
    mov qword [rsp+56], 0
    mov qword [rsp+64], WINDOW_H
    mov rax, [rel framebuffer]
    mov [rsp+72], rax
    lea rax, [rel bmi]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call SetDIBitsToDevice

    ; ReleaseDC(hwnd, hdc)
    mov rcx, [rel hwnd_main]
    mov rdx, rbx
    call ReleaseDC

    add rsp, 104
    pop rbx
    pop rbp
    ret


; ============================================================================
; frame_delay — sleep for remainder of frame to target ~60fps
; ============================================================================
frame_delay:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    lea rcx, [rel perf_end]
    call QueryPerformanceCounter

    mov rax, [rel perf_end]
    sub rax, [rel perf_start]

    imul rax, 1000
    mov rcx, [rel perf_freq]
    test rcx, rcx
    jz .no_sleep
    xor edx, edx
    div rcx

    cmp eax, 16
    jge .no_sleep

    mov ecx, 16
    sub ecx, eax
    call Sleep

.no_sleep:
    add rsp, 32
    pop rbp
    ret

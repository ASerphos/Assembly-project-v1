; ============================================================================
; Hollow Knight Assembly Demo — Main Entry Point
; X11 window creation, game loop, event handling, cleanup
; ============================================================================

%include "constants.inc"

; ---- External C / X11 functions ----
extern XOpenDisplay
extern XCloseDisplay
extern XCreateSimpleWindow
extern XDestroyWindow
extern XMapWindow
extern XSelectInput
extern XNextEvent
extern XPending
extern XFlush
extern XLookupKeysym
extern XDefaultScreen
extern XDefaultVisual
extern XDefaultDepth
extern XDefaultGC
extern XRootWindow
extern XBlackPixel
extern XCreateImage
extern XPutImage
extern XStoreName
extern XInternAtom
extern XSetWMProtocols

extern calloc
extern free
extern clock_gettime
extern nanosleep
extern exit

; ---- Game module functions (other .asm files) ----
extern render_frame
extern init_level
extern init_enemies
extern update_player
extern update_enemies
extern check_enemy_collisions
extern init_sprites

; ---- Globals exported from this module ----
global main
global display_ptr
global window_id
global gc_ptr
global ximage_ptr
global framebuffer
global screen_depth
global visual_ptr
global game_running
global frame_count
global game_state

; Input state (read by player.asm)
global key_left
global key_right
global key_up
global key_down
global key_jump
global key_attack
global key_dash
global key_jump_pressed   ; single-frame trigger
global key_attack_pressed
global key_dash_pressed

; Player state (shared across modules)
global player_x
global player_y
global player_vx
global player_vy
global player_hp
global player_facing
global player_on_ground
global player_state
global player_anim_frame
global player_anim_timer
global player_invuln_timer
global player_dash_timer
global player_dash_cooldown
global player_slash_active
global player_slash_timer
global player_slash_cooldown
global player_slash_x
global player_slash_y

; Enemy state
global enemies
global num_enemies

section .data
    window_title:   db "Hollow Knight - Assembly Demo", 0
    wm_delete_str:  db "WM_DELETE_WINDOW", 0
    err_display:    db "Error: Cannot open X display", 10, 0

section .bss
    ; ---- X11 state ----
    display_ptr:    resq 1
    window_id:      resq 1
    gc_ptr:         resq 1
    ximage_ptr:     resq 1
    framebuffer:    resq 1      ; pointer to pixel buffer
    visual_ptr:     resq 1
    screen_num:     resd 1
    screen_depth:   resd 1
    wm_delete_atom: resq 1

    event_buf:      resb 192    ; XEvent union (largest is 192 bytes)

    ; ---- Input state ----
    key_left:       resb 1
    key_right:      resb 1
    key_up:         resb 1
    key_down:       resb 1
    key_jump:       resb 1      ; held state
    key_attack:     resb 1
    key_dash:       resb 1
    key_jump_pressed:   resb 1  ; single-frame press trigger
    key_attack_pressed: resb 1
    key_dash_pressed:   resb 1

    ; ---- Player state ----
    player_x:       resd 1      ; fixed-point (<<8)
    player_y:       resd 1
    player_vx:      resd 1
    player_vy:      resd 1
    player_hp:      resd 1
    player_facing:  resd 1      ; 0=right, 1=left
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

    ; ---- Enemy array ----
    enemies:        resb ENEMY_STRUCT_SIZE * MAX_ENEMIES
    num_enemies:    resd 1

    ; ---- Game state ----
    game_running:   resd 1
    game_state:     resd 1      ; 0=title, 1=playing, 2=dead
    frame_count:    resq 1

    ; ---- Timing ----
    time_start:     resb 16     ; struct timespec
    time_end:       resb 16
    sleep_req:      resb 16

section .text

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
    sub rsp, 8              ; align stack to 16 bytes

    ; ---- XOpenDisplay(NULL) ----
    xor edi, edi
    call XOpenDisplay
    test rax, rax
    jz .init_fail
    mov [rel display_ptr], rax
    mov rbx, rax            ; rbx = display (callee-saved)

    ; ---- screen_num = XDefaultScreen(display) ----
    mov rdi, rbx
    call XDefaultScreen
    mov [rel screen_num], eax
    mov r12d, eax           ; r12d = screen_num

    ; ---- root = XRootWindow(display, screen) ----
    mov rdi, rbx
    mov esi, r12d
    call XRootWindow
    mov r13, rax            ; r13 = root window

    ; ---- visual = XDefaultVisual(display, screen) ----
    mov rdi, rbx
    mov esi, r12d
    call XDefaultVisual
    mov [rel visual_ptr], rax

    ; ---- depth = XDefaultDepth(display, screen) ----
    mov rdi, rbx
    mov esi, r12d
    call XDefaultDepth
    mov [rel screen_depth], eax

    ; ---- gc = XDefaultGC(display, screen) ----
    mov rdi, rbx
    mov esi, r12d
    call XDefaultGC
    mov [rel gc_ptr], rax

    ; ---- black = XBlackPixel(display, screen) ----
    mov rdi, rbx
    mov esi, r12d
    call XBlackPixel
    mov r14, rax            ; r14 = black pixel

    ; ---- XCreateSimpleWindow(display, root, 0, 0, 640, 480, 0, black, black) ----
    ; 9 args: 6 in regs + 3 on stack
    sub rsp, 24             ; 3 stack args (+ already aligned)
    mov [rsp], r14          ; arg7: border_pixel = black
    mov qword [rsp+8], 0    ; arg8: border_width... wait

    ; Actually: XCreateSimpleWindow(display, parent, x, y, width, height, border_w, border, background)
    ; Args: rdi=display, rsi=parent, edx=x, ecx=y, r8d=width, r9d=height, [stack]=border_w, [stack+8]=border, [stack+16]=bg
    mov qword [rsp], 0      ; arg7: border_width = 0
    mov [rsp+8], r14        ; arg8: border_pixel = black
    mov [rsp+16], r14       ; arg9: background = black
    mov rdi, rbx            ; arg1: display
    mov rsi, r13            ; arg2: parent = root
    xor edx, edx            ; arg3: x = 0
    xor ecx, ecx            ; arg4: y = 0
    mov r8d, WINDOW_W       ; arg5: width = 640
    mov r9d, WINDOW_H       ; arg6: height = 480
    call XCreateSimpleWindow
    add rsp, 24
    mov [rel window_id], rax
    mov r15, rax            ; r15 = window

    ; ---- XStoreName(display, window, title) ----
    mov rdi, rbx
    mov rsi, r15
    lea rdx, [rel window_title]
    call XStoreName

    ; ---- Set up WM_DELETE_WINDOW protocol ----
    mov rdi, rbx
    lea rsi, [rel wm_delete_str]
    xor edx, edx            ; only_if_exists = False
    call XInternAtom
    mov [rel wm_delete_atom], rax

    ; XSetWMProtocols(display, window, &atom, 1)
    mov rdi, rbx
    mov rsi, r15
    lea rdx, [rel wm_delete_atom]
    mov ecx, 1
    call XSetWMProtocols

    ; ---- XSelectInput(display, window, event_mask) ----
    mov rdi, rbx
    mov rsi, r15
    mov rdx, EVENT_MASK
    call XSelectInput

    ; ---- XMapWindow(display, window) ----
    mov rdi, rbx
    mov rsi, r15
    call XMapWindow

    ; ---- Allocate framebuffer: calloc(W*H, 4) ----
    mov edi, WINDOW_W * WINDOW_H
    mov esi, BPP
    call calloc
    test rax, rax
    jz .init_fail
    mov [rel framebuffer], rax

    ; ---- XCreateImage(display, visual, depth, ZPixmap, 0, data, w, h, 32, 0) ----
    ; 10 args: 6 in regs + 4 on stack
    sub rsp, 32
    mov dword [rsp], WINDOW_W       ; arg7: width
    mov dword [rsp+8], WINDOW_H     ; arg8: height
    mov dword [rsp+16], 32          ; arg9: bitmap_pad
    mov dword [rsp+24], 0           ; arg10: bytes_per_line (auto)
    mov rdi, rbx                    ; arg1: display
    mov rsi, [rel visual_ptr]       ; arg2: visual
    mov edx, [rel screen_depth]     ; arg3: depth
    mov ecx, ZPixmap                ; arg4: format
    xor r8d, r8d                    ; arg5: offset = 0
    mov r9, [rel framebuffer]       ; arg6: data
    call XCreateImage
    add rsp, 32
    test rax, rax
    jz .init_fail
    mov [rel ximage_ptr], rax

    ; ---- Flush to show window ----
    mov rdi, rbx
    call XFlush

    ; ---- Initialize game state ----
    call init_game_state

    ; ---- Initialize sprites (palette) ----
    call init_sprites

    ; ---- Initialize level ----
    call init_level

    ; ---- Initialize enemies ----
    call init_enemies

    ; ---- Mark game as running ----
    mov dword [rel game_running], 1
    mov dword [rel game_state], 1    ; start playing directly

    ; ============================================================
    ; MAIN GAME LOOP
    ; ============================================================
.game_loop:
    ; 1. Record frame start time
    mov edi, CLOCK_MONOTONIC
    lea rsi, [rel time_start]
    call clock_gettime

    ; 2. Clear single-frame press triggers
    mov byte [rel key_jump_pressed], 0
    mov byte [rel key_attack_pressed], 0
    mov byte [rel key_dash_pressed], 0

    ; 3. Process all pending X11 events
    call process_events

    ; 4. Check if game should exit
    cmp dword [rel game_running], 0
    je .game_exit

    ; 5. Update game logic
    call update_player
    call update_enemies
    call check_enemy_collisions

    ; 6. Render frame to framebuffer
    call render_frame

    ; 7. Blit framebuffer to window via XPutImage
    ; XPutImage(display, drawable, gc, image, src_x, src_y, dst_x, dst_y, width, height)
    ; 10 args: 6 in regs + 4 on stack
    sub rsp, 32
    mov dword [rsp], 0              ; arg7: dst_x = 0
    mov dword [rsp+8], 0            ; arg8: dst_y = 0
    mov dword [rsp+16], WINDOW_W    ; arg9: width
    mov dword [rsp+24], WINDOW_H    ; arg10: height
    mov rdi, [rel display_ptr]      ; arg1: display
    mov rsi, [rel window_id]        ; arg2: window
    mov rdx, [rel gc_ptr]           ; arg3: gc
    mov rcx, [rel ximage_ptr]       ; arg4: image
    xor r8d, r8d                    ; arg5: src_x = 0
    xor r9d, r9d                    ; arg6: src_y = 0
    call XPutImage
    add rsp, 32

    ; 8. Flush display
    mov rdi, [rel display_ptr]
    call XFlush

    ; 9. Frame timing — sleep for remainder
    call frame_delay

    ; 10. Increment frame counter
    inc qword [rel frame_count]

    jmp .game_loop

    ; ============================================================
    ; CLEANUP & EXIT
    ; ============================================================
.game_exit:
    ; XDestroyWindow
    mov rdi, [rel display_ptr]
    mov rsi, [rel window_id]
    call XDestroyWindow

    ; XCloseDisplay
    mov rdi, [rel display_ptr]
    call XCloseDisplay

    xor eax, eax            ; return 0
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.init_fail:
    mov edi, 1
    call exit


; ============================================================================
; init_game_state — set player and game to initial values
; ============================================================================
init_game_state:
    ; Player starts at logical (40, 180) — near bottom-left on ground
    ; Fixed-point: multiply by 256
    mov dword [rel player_x], 40 * 256
    mov dword [rel player_y], 180 * 256
    mov dword [rel player_vx], 0
    mov dword [rel player_vy], 0
    mov dword [rel player_hp], MAX_HP
    mov dword [rel player_facing], 0     ; facing right
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
    ; Clear input
    mov byte [rel key_left], 0
    mov byte [rel key_right], 0
    mov byte [rel key_up], 0
    mov byte [rel key_down], 0
    mov byte [rel key_jump], 0
    mov byte [rel key_attack], 0
    mov byte [rel key_dash], 0
    ret

; Make init_game_state available for respawn
global init_game_state


; ============================================================================
; process_events — handle all pending X11 events (non-blocking)
; ============================================================================
process_events:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

.event_loop:
    mov rdi, [rel display_ptr]
    call XPending
    test eax, eax
    jz .events_done

    mov rdi, [rel display_ptr]
    lea rsi, [rel event_buf]
    call XNextEvent

    ; Read event type
    mov eax, [rel event_buf + XEVENT_TYPE]

    cmp eax, X11_KeyPress
    je .handle_keypress
    cmp eax, X11_KeyRelease
    je .handle_keyrelease
    cmp eax, X11_ButtonPress
    je .handle_buttonpress
    cmp eax, X11_ButtonRelease
    je .handle_buttonrelease
    cmp eax, X11_ClientMessage
    je .handle_client_message
    jmp .event_loop

; ---- Keyboard press ----
.handle_keypress:
    lea rdi, [rel event_buf]
    xor esi, esi
    call XLookupKeysym

    cmp eax, XK_a
    je .press_left
    cmp eax, XK_d
    je .press_right
    cmp eax, XK_w
    je .press_up
    cmp eax, XK_s
    je .press_down
    cmp eax, XK_space
    je .press_jump
    cmp eax, XK_Escape
    je .press_quit
    cmp eax, XK_q
    je .press_quit
    jmp .event_loop

.press_left:
    mov byte [rel key_left], 1
    jmp .event_loop
.press_right:
    mov byte [rel key_right], 1
    jmp .event_loop
.press_up:
    mov byte [rel key_up], 1
    jmp .event_loop
.press_down:
    mov byte [rel key_down], 1
    jmp .event_loop
.press_jump:
    cmp byte [rel key_jump], 0
    jne .event_loop          ; already held, no new press
    mov byte [rel key_jump], 1
    mov byte [rel key_jump_pressed], 1
    jmp .event_loop
.press_quit:
    mov dword [rel game_running], 0
    jmp .events_done

; ---- Keyboard release ----
.handle_keyrelease:
    lea rdi, [rel event_buf]
    xor esi, esi
    call XLookupKeysym

    cmp eax, XK_a
    je .release_left
    cmp eax, XK_d
    je .release_right
    cmp eax, XK_w
    je .release_up
    cmp eax, XK_s
    je .release_down
    cmp eax, XK_space
    je .release_jump
    jmp .event_loop

.release_left:
    mov byte [rel key_left], 0
    jmp .event_loop
.release_right:
    mov byte [rel key_right], 0
    jmp .event_loop
.release_up:
    mov byte [rel key_up], 0
    jmp .event_loop
.release_down:
    mov byte [rel key_down], 0
    jmp .event_loop
.release_jump:
    mov byte [rel key_jump], 0
    jmp .event_loop

; ---- Mouse button press ----
.handle_buttonpress:
    mov eax, [rel event_buf + XBUTTON_BUTTON]
    cmp eax, Button1
    je .press_attack
    cmp eax, Button3
    je .press_dash
    jmp .event_loop

.press_attack:
    cmp byte [rel key_attack], 0
    jne .event_loop
    mov byte [rel key_attack], 1
    mov byte [rel key_attack_pressed], 1
    jmp .event_loop
.press_dash:
    cmp byte [rel key_dash], 0
    jne .event_loop
    mov byte [rel key_dash], 1
    mov byte [rel key_dash_pressed], 1
    jmp .event_loop

; ---- Mouse button release ----
.handle_buttonrelease:
    mov eax, [rel event_buf + XBUTTON_BUTTON]
    cmp eax, Button1
    je .release_attack
    cmp eax, Button3
    je .release_dash
    jmp .event_loop

.release_attack:
    mov byte [rel key_attack], 0
    jmp .event_loop
.release_dash:
    mov byte [rel key_dash], 0
    jmp .event_loop

; ---- WM_DELETE_WINDOW (window close button) ----
.handle_client_message:
    ; ClientMessage data starts at offset 56 in XClientMessageEvent
    mov rax, [rel event_buf + 56]
    cmp rax, [rel wm_delete_atom]
    jne .event_loop
    mov dword [rel game_running], 0
    jmp .events_done

.events_done:
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; frame_delay — sleep for the remainder of the frame to target ~60fps
; ============================================================================
frame_delay:
    push rbp
    mov rbp, rsp

    ; Get end time
    mov edi, CLOCK_MONOTONIC
    lea rsi, [rel time_end]
    call clock_gettime

    ; Compute elapsed = (end.sec - start.sec) * 1e9 + (end.nsec - start.nsec)
    mov rax, [rel time_end]
    sub rax, [rel time_start]
    imul rax, BILLION
    mov rcx, [rel time_end + 8]
    sub rcx, [rel time_start + 8]
    add rax, rcx               ; rax = elapsed nanoseconds

    ; remaining = FRAME_NS - elapsed
    mov rcx, FRAME_NS
    sub rcx, rax
    jle .no_sleep              ; already over budget

    ; nanosleep({0, remaining}, NULL)
    mov qword [rel sleep_req], 0
    mov [rel sleep_req + 8], rcx
    lea rdi, [rel sleep_req]
    xor esi, esi
    call nanosleep

.no_sleep:
    pop rbp
    ret

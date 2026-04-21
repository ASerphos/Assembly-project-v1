; ============================================================================
; Hollow Knight Assembly Demo — Enemy Logic
; Patrol AI, combat interactions
; ============================================================================

%include "constants.inc"

extern enemies
extern num_enemies
extern player_x, player_y
extern player_hp, player_facing
extern player_vx, player_vy
extern player_invuln_timer
extern player_slash_active
extern player_slash_x, player_slash_y
extern respawn_player
extern aabb_overlap

global init_enemies
global update_enemies
global check_enemy_collisions

section .text

; ============================================================================
; init_enemies — place 3 enemies on ground platform(s)
; ============================================================================
init_enemies:
    push rbp
    mov rbp, rsp
    push rbx

    mov dword [rel num_enemies], 3
    lea rbx, [rel enemies]

    ; Enemy 0: patrols on the ground floor, left portion
    ; y should be on top of row 14 (ground), so logical y = 14*16 - ENEMY_H = 212
    mov dword [rbx + ENM_X], 80 * 256
    mov dword [rbx + ENM_Y], 212 * 256
    mov dword [rbx + ENM_VX], -ENEMY_SPEED
    mov dword [rbx + ENM_HP], ENEMY_HP_MAX
    mov dword [rbx + ENM_ALIVE], 1
    mov dword [rbx + ENM_DIR], 1                  ; starting left
    mov dword [rbx + ENM_HIT_TIMER], 0
    mov dword [rbx + ENM_PLAT_LEFT], 24 * 256
    mov dword [rbx + ENM_PLAT_RIGHT], 140 * 256
    mov dword [rbx + ENM_ANIM], 0

    ; Enemy 1: patrols on mid platform (row 8, cols 8-11 -> x: 128-192)
    add rbx, ENEMY_STRUCT_SIZE
    mov dword [rbx + ENM_X], 150 * 256
    mov dword [rbx + ENM_Y], 116 * 256            ; row 8 top = 128; minus ENEMY_H=12
    mov dword [rbx + ENM_VX], ENEMY_SPEED
    mov dword [rbx + ENM_HP], ENEMY_HP_MAX
    mov dword [rbx + ENM_ALIVE], 1
    mov dword [rbx + ENM_DIR], 0                  ; starting right
    mov dword [rbx + ENM_HIT_TIMER], 0
    mov dword [rbx + ENM_PLAT_LEFT], 128 * 256
    mov dword [rbx + ENM_PLAT_RIGHT], 176 * 256
    mov dword [rbx + ENM_ANIM], 0

    ; Enemy 2: patrols on ground floor, right portion
    add rbx, ENEMY_STRUCT_SIZE
    mov dword [rbx + ENM_X], 240 * 256
    mov dword [rbx + ENM_Y], 212 * 256
    mov dword [rbx + ENM_VX], ENEMY_SPEED
    mov dword [rbx + ENM_HP], ENEMY_HP_MAX
    mov dword [rbx + ENM_ALIVE], 1
    mov dword [rbx + ENM_DIR], 0
    mov dword [rbx + ENM_HIT_TIMER], 0
    mov dword [rbx + ENM_PLAT_LEFT], 180 * 256
    mov dword [rbx + ENM_PLAT_RIGHT], 288 * 256
    mov dword [rbx + ENM_ANIM], 0

    pop rbx
    pop rbp
    ret


; ============================================================================
; update_enemies — move and animate all alive enemies
; ============================================================================
update_enemies:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea rbx, [rel enemies]
    mov r12d, [rel num_enemies]
    xor ecx, ecx
.loop:
    cmp ecx, r12d
    jge .done

    cmp dword [rbx + ENM_ALIVE], 0
    je .next

    ; Decrement hit timer
    mov eax, [rbx + ENM_HIT_TIMER]
    test eax, eax
    jz .no_hit_dec
    dec eax
    mov [rbx + ENM_HIT_TIMER], eax
.no_hit_dec:

    ; Move: x += vx
    mov eax, [rbx + ENM_X]
    add eax, [rbx + ENM_VX]
    mov [rbx + ENM_X], eax

    ; Check bounds and reverse
    cmp eax, [rbx + ENM_PLAT_LEFT]
    jg .check_right_bound
    ; Hit left bound; reverse
    mov eax, [rbx + ENM_PLAT_LEFT]
    mov [rbx + ENM_X], eax
    mov dword [rbx + ENM_VX], ENEMY_SPEED
    mov dword [rbx + ENM_DIR], 0          ; facing right now
    jmp .anim

.check_right_bound:
    cmp eax, [rbx + ENM_PLAT_RIGHT]
    jl .anim
    mov eax, [rbx + ENM_PLAT_RIGHT]
    mov [rbx + ENM_X], eax
    mov dword [rbx + ENM_VX], -ENEMY_SPEED
    mov dword [rbx + ENM_DIR], 1          ; facing left

.anim:
    ; Advance animation every ~12 frames
    mov eax, [rbx + ENM_ANIM]
    inc eax
    mov [rbx + ENM_ANIM], eax

.next:
    add rbx, ENEMY_STRUCT_SIZE
    inc ecx
    jmp .loop
.done:
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; check_enemy_collisions — slash vs enemies, enemy vs player
; ============================================================================
check_enemy_collisions:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    ; Player bbox (integer logical)
    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT
    add eax, KNIGHT_HB_OX
    mov r12d, eax                   ; player_bb_x
    mov eax, [rel player_y]
    sar eax, FIXED_SHIFT
    add eax, KNIGHT_HB_OY
    mov r13d, eax                   ; player_bb_y

    lea rbx, [rel enemies]
    xor ecx, ecx

.eloop:
    cmp ecx, [rel num_enemies]
    jge .done
    cmp dword [rbx + ENM_ALIVE], 0
    je .enext

    ; --- Slash vs enemy ---
    cmp dword [rel player_slash_active], 0
    je .skip_slash
    cmp dword [rbx + ENM_HIT_TIMER], 0
    jne .skip_slash             ; enemy already in hurt stun this frame

    ; aabb_overlap(slash_x, slash_y, SLASH_W, SLASH_H, enemy_x, enemy_y, ENEMY_HITBOX_W, ENEMY_HITBOX_H)
    push rcx
    push rbx
    sub rsp, 16
    mov dword [rsp], ENEMY_HITBOX_W
    mov dword [rsp+8], ENEMY_HITBOX_H

    mov edi, [rel player_slash_x]
    mov esi, [rel player_slash_y]
    mov edx, SLASH_W
    mov ecx, SLASH_H
    mov r8d, [rbx + ENM_X]
    sar r8d, FIXED_SHIFT
    mov r9d, [rbx + ENM_Y]
    sar r9d, FIXED_SHIFT
    call aabb_overlap
    add rsp, 16
    pop rbx
    pop rcx

    test eax, eax
    jz .skip_slash
    ; Hit!
    mov eax, [rbx + ENM_HP]
    dec eax
    mov [rbx + ENM_HP], eax
    mov dword [rbx + ENM_HIT_TIMER], 8
    test eax, eax
    jg .skip_slash
    ; Dead
    mov dword [rbx + ENM_ALIVE], 0
.skip_slash:

    ; --- Enemy vs player (deal damage) ---
    cmp dword [rel player_invuln_timer], 0
    jne .enext

    push rcx
    push rbx
    sub rsp, 16
    mov dword [rsp], ENEMY_HITBOX_W
    mov dword [rsp+8], ENEMY_HITBOX_H

    mov edi, r12d
    mov esi, r13d
    mov edx, KNIGHT_HITBOX_W
    mov ecx, KNIGHT_HITBOX_H
    mov r8d, [rbx + ENM_X]
    sar r8d, FIXED_SHIFT
    mov r9d, [rbx + ENM_Y]
    sar r9d, FIXED_SHIFT
    call aabb_overlap
    add rsp, 16
    pop rbx
    pop rcx

    test eax, eax
    jz .enext

    ; Player takes damage
    mov eax, [rel player_hp]
    dec eax
    mov [rel player_hp], eax
    mov dword [rel player_invuln_timer], INVULN_FRAMES

    ; Knockback: push player away from enemy
    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT
    mov edx, [rbx + ENM_X]
    sar edx, FIXED_SHIFT
    cmp eax, edx
    jge .kb_right
    mov dword [rel player_vx], -1024
    mov dword [rel player_vy], -500
    jmp .check_death
.kb_right:
    mov dword [rel player_vx], 1024
    mov dword [rel player_vy], -500

.check_death:
    mov eax, [rel player_hp]
    test eax, eax
    jg .enext
    ; Dead — respawn player and reset enemies
    call respawn_player
    call init_enemies
    jmp .done

.enext:
    add rbx, ENEMY_STRUCT_SIZE
    inc ecx
    jmp .eloop

.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

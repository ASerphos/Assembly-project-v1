; ============================================================================
; Hollow Knight Assembly Demo — Level Data & Tilemap
; ============================================================================
; Tilemap: 20 cols x 15 rows of 16x16 logical pixel tiles.
; Tile values: 0=empty, 1=solid (ground/wall), 2=platform
; ============================================================================

%include "constants.inc"

global level_map
global init_level
global get_tile
global is_solid_at

section .data

; 20 cols x 15 rows tilemap
; Row 0 is top, row 14 is bottom
level_map:
    ;    0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 0 ceiling corners
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 1
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 2
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 3
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 2, 2, 2, 2, 0, 0, 1   ; row 4 high-right platform
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 5
    db   1,0,0,2,2,2,2,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 6 left platform
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 7
    db   1,0,0,0,0,0,0,0,2,2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 1   ; row 8 mid platform
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 9
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 1   ; row 10 right platform
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 11
    db   1,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1   ; row 12
    db   1,0,2,2,2,2,0,0,0,0, 2, 2, 2, 2, 0, 0, 2, 2, 2, 1   ; row 13 low platforms
    db   1,1,1,1,1,1,1,1,1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1   ; row 14 ground

section .text

; ============================================================================
; init_level — nothing to init; map is static data
; ============================================================================
init_level:
    ret

; ============================================================================
; get_tile(col, row) -> tile value in al
; Args:  edi = col, esi = row
; Returns: al = tile value (0 if out of bounds = empty, but we return 1 for
;          safety outside map to treat outside as solid wall)
; Clobbers: rax, rcx
; ============================================================================
get_tile:
    ; Bounds check
    cmp edi, 0
    jl  .oob_solid
    cmp edi, MAP_COLS
    jge .oob_solid
    cmp esi, 0
    jl  .oob_solid
    cmp esi, MAP_ROWS
    jge .oob_empty          ; falling below map = empty (death pit if one existed)

    ; offset = row * MAP_COLS + col
    mov eax, esi
    imul eax, MAP_COLS
    add eax, edi
    lea rcx, [rel level_map]
    movzx eax, byte [rcx + rax]
    ret

.oob_solid:
    mov eax, 1              ; outside horizontal/top bounds = solid wall
    ret
.oob_empty:
    xor eax, eax
    ret

; ============================================================================
; is_solid_at(logical_x, logical_y) -> rax: 1 if tile is solid, 0 if not
; Args:  edi = logical x (integer pixels), esi = logical y
; Note: PLATFORM tiles are handled specially in collision code — this returns
;       1 only for truly solid tiles (ground/wall).
; ============================================================================
is_solid_at:
    push rbp
    mov rbp, rsp
    ; col = x / TILE_SIZE
    mov eax, edi
    ; Handle negative coords — treat as solid (outside bounds)
    test eax, eax
    js .oob_solid
    cdq
    mov ecx, TILE_SIZE
    idiv ecx
    mov edi, eax            ; edi = col

    mov eax, esi
    test eax, eax
    js .oob_solid
    cdq
    idiv ecx
    mov esi, eax            ; esi = row

    call get_tile
    ; al is tile value; return 1 if tile == TILE_SOLID
    cmp al, TILE_SOLID
    jne .not_solid
    mov eax, 1
    pop rbp
    ret
.not_solid:
    xor eax, eax
    pop rbp
    ret
.oob_solid:
    mov eax, 1
    pop rbp
    ret

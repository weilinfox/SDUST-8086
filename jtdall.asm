io8253a     equ 280h
io8253b     equ 281h
io8253c     equ 282h
io8253ctl   equ 283h
io8253ctlw  equ 76h

io8255a     equ 298h
io8255b     equ 299h
io8255c     equ 29ah
io8255ctl   equ 29bh

icw1        equ 2b0h
icw2        equ 2b1h
icw3        equ 2b1h
icw4        equ 2b1h
ocw1        equ 2b1h
ocw2        equ 2b0h
ocw3        equ 2b0h

;����
;280~287H   8253CS
;CLK0       1MHz
;OUT0       CLK1
;GATE0      +5V
;OUT1       �߼� ��Ȧ
;GATE1      +5V

;298~29FH   8255CS
;PA         PL4 ����� A-DP
;PB         PL6 ����� S0-S5
;PC         PL2 LED

;2B0~2B7H   8259CS
;INT        NOT_A
;NOT_Y      IRQ
;IR0        PULSE2+
;IR1        PULSE1+
;INTA       +5V

;�����������������һ�� D ������
;������ CLK �� OUT1
;������ SD/CD �� +5V

data segment
    msgclk db 13,10,'Clock tick','$'
    clk byte 1
    
    led db 01000100b,01000100b,01000100b,01000100b,01000100b,01000100b,01000100b,01000100b, \
            00h,01000010b,00h,01000010b,\
            00100001b,00100001b,00100001b,00100001b,00100001b,00100001b,00100001b,00100001b, \
            00h,10000001b,00h,10000001b, \
            01000001b ; ��������� ���һ��Ϊ�Ȼ���
    digits db 66h,66h,4fh,4fh,5bh,5bh,06h,06h, \
            00h,00h,00h,00h,\
            66h,66h,4fh,4fh,5bh,5bh,06h,06h, \
            00h,00h,00h,00h, \
            00h ; ���������
    dpos db 1fh,1fh,1fh,1fh,1fh,1fh,1fh,1fh, \
            3fh,3fh,3fh,3fh,\
            3eh,3eh,3eh,3eh,3eh,3eh,3eh,3eh, \
            3fh,3fh,3fh,3fh, \
            3fh ; ���������
    ambu byte 0 ; �Ȼ���
    time byte 0 ; ��ǰʱ�� 0-23 �Ȼ��� 24
    ;digits db 3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6fh,00h ; �������������
    count byte 10    ; ����ܵ�ǰ����
    
    msgint0 db 13,10,'Ambulance come','$'
    msgint1 db 13,10,'Ambulance gone','$'
    msgint2 db 13,10,'Already come','$'
    msgint3 db 13,10,'No ambulance','$'
    intnum db 00H
data ends

stk segment stack
    dw 0,0,0,0,0,0,0,0,0,0
stk ends

code segment
    assume cs:code, ds:data, ss:stk
start:
    ; ��ʼ���ж�
    mov ax, cs
    mov ds, ax
    mov dx, offset int3
    mov ax, 250bh
    int 21h
    cli
    in al, 21h
    and al, 0f7h
    out 21h, al
    mov al, 11h
    mov dx, icw1
    out dx, al 
    mov al, 08h
    mov dx, icw2
    out dx, al
    mov al, 01h
    mov dx, icw4
    out dx, al
    mov al, 00h
    mov dx, ocw1
    out dx, al
    mov cx, 0fffh

    mov dx, seg data
    mov ds, dx
    mov dx, seg stk
    mov ss, dx
    
    ;��ʼ��8253
    mov dx, io8253ctl
    mov al, 00110110b   ; ͨ��0������ʽ3 ��ֵ50000
    out dx, al
    mov dx, io8253a
    mov ax, 50000
    out dx, al
    mov al, ah
    out dx, al
    mov dx, io8253ctl
    mov al, 01010100b   ; ͨ��1������ʽ2 ��ֵ10 ֻ��д��8λ
    out dx, al
    mov dx, io8253b
    mov al, 10
    out dx, al
    
    ; ��ʼ��8255
    mov dx,io8255ctl    ;��8255��ΪA C�����
    mov al,80h
    out dx,al
    mov dx, io8255a
    mov al, 0
    out dx, al
    mov dx, io8255c
    out dx, al          ;����ʾ
    
    sti ; ���ж�
    
bigloop:
    ; ��ȡʱ�� 0.5s ����һ��
    call getclk
    dec al
    test al, 255
    jnz nowork
    
    mov al, byte ptr clk
    test al, 255
    jnz oldsec

    mov dx, offset msgclk
    mov ah, 09h
    int 21h
    ; ��ֹ�������
    mov byte ptr clk, 1
    
    ; ����ܺ�LED
    xor ax, ax
    
    mov si,offset dpos
    mov al, byte ptr time
    add si, ax
    mov al, byte ptr [si]
    mov dx, io8255b
    out dx, al
    mov si,offset digits
    mov al, byte ptr time
    add si, ax
    mov al, byte ptr [si]
    mov dx, io8255a
    out dx, al

    mov si,offset led
    mov al, byte ptr time
    add si, ax
    mov al, byte ptr [si]
    mov dx, io8255c
    out dx, al
    
    ; �Ƿ�Ȼ������
    test byte ptr ambu, 255
    jnz incircle
    
    ; ʱ��++
    inc byte ptr time
    cmp byte ptr time, 24
    jb incircle
    mov byte ptr time, 0
    
incircle:
    jmp oldsec
nowork:
    mov byte ptr clk, 0
oldsec:
    call readkey
    jnz quit
    call delay100ms
    jmp bigloop

quit:
    mov ah, 4ch
    int 21h

int3:
    cli ;���ж�
    mov dx, ocw3
    mov al, 0ah
    out dx, al
    in al, dx
    mov byte ptr intnum, al
    cmp al, 00h
    jz iend
    and al, 03h
    test al, 01h
    jnz itr0
    test al, 02h
    jnz itr1
    jmp iend
itr0:
    mov ax, seg data
    mov ds, ax
    test byte ptr ambu, 255 ; ����Ѿ��ھȻ���״̬����ʾ�Ѿ�����
    jnz hasemb
    mov dx, offset msgint0
    mov ah, 09h
    int 21h
    mov byte ptr ambu, 1
    mov byte ptr time, 24
    jmp enditr0
hasemb:
    mov dx, offset msgint2
    mov ah, 09h
    int 21h
enditr0:
    mov al, intnum
    test al, 02h
    jnz itr1
    jmp iend
itr1:
    mov ax, seg data
    mov ds, ax
    test byte ptr ambu, 255 ; ��������ھȻ���״̬����ʾ�޾Ȼ���
    jz noemb
    mov dx, offset msgint1
    mov ah, 09h
    int 21h
    mov byte ptr ambu, 0
    mov byte ptr time, 0
    jmp iend
noemb:
    mov dx, offset msgint3
    mov ah, 09h
    int 21h
iend:
    mov al, 20h
    out 20h, al
    jmp next
    in al, 21h
    or al, 08h
    out 21h, al
    ;mov ah, 4ch
    ;int 21h
next:
    sti
    iret    ; �жϷ���

readkey proc neer
    ; ��һ������
    push dx
    mov ah, 06h
    mov dl, 0ffh
    int 21h
    pop dx
    ret
readkey endp
    
getclk proc near
    ; ��8253b��al
    push dx
    mov dx, io8253b
    in al, dx
    pop dx
    ret
getclk endp

delay100ms proc
    push dx 
    push cx
    push bx
    push ax
    mov bx,04e8h
lp22:
    mov cx,0dbh
lp21:
    pushf
    popf
    loop lp21
    dec bx
    jnz lp22
    pop ax
    pop bx
    pop cx
    pop dx
    ret
delay100ms endp

code ends

end start

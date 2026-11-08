    .section .text
    .globl main
main:
    li t0, -1
    addi t1, zero, 1
    add zero, t0, t0
    bne zero, x0, fail
    slt t2, t0, t1
    bne t2, t1, fail
    sltu t2, t0, t1
    bne t2, zero, fail
    bltu t0, t1, fail
    bge t0, t1, fail
    bgeu t0, t1, 1f
    j fail
1:  blt t0, t1, 2f
    j fail
2:  srai t2, t0, 31
    bne t2, t0, fail
    srl t2, t0, t0
    bne t2, t1, fail
    sll t2, t1, t0
    lui t3, 0x80000
    bne t2, t3, fail
    addi sp, sp, -16
    sw zero, 0(sp)
    sb t0, 1(sp)
    sh t0, 2(sp)
    lb t2, 1(sp)
    bne t2, t0, fail
    lbu t2, 1(sp)
    li t3, 255
    bne t2, t3, fail
    lh t2, 2(sp)
    bne t2, t0, fail
    lhu t2, 2(sp)
    li t3, 65535
    bne t2, t3, fail
    lw t2, 0(sp)
    li t3, -256
    bne t2, t3, fail
    addi sp, sp, 16
    fence
    li a0, 0
    ret
fail:
    li a0, 1
    ret

#!/bin/sh
set -e
prefix='/opt/riscv'
rpath=$prefix/bin/
# clearing test dir
rm -rf ../testspace
mkdir ../testspace
# compiling rom
${rpath}riscv32-unknown-elf-as -o ../sys/rom.o -march=rv32i ../sys/rom.s
# compiling testcase
cp ../testcase/fpga/${1%.*}.c ../testspace/test.c
${rpath}riscv32-unknown-elf-gcc -o ../testspace/test.o -I ../sys -c ../testspace/test.c -O2 -march=rv32i -mabi=ilp32 -Wall
# linking
${rpath}riscv32-unknown-elf-ld -T ../sys/memory.ld ../sys/rom.o ../testspace/test.o -L $prefix/riscv32-unknown-elf/lib/ -L $prefix/lib/gcc/riscv32-unknown-elf/10.1.0/ -lc -lgcc -lm -lnosys -o ../testspace/test.om
# converting to verilog format
${rpath}riscv32-unknown-elf-objcopy -O verilog ../testspace/test.om ../testspace/test.data
# converting to binary format(for ram uploading)
${rpath}riscv32-unknown-elf-objcopy -O binary ../testspace/test.om ../testspace/test.bin
# decompile (for debugging)
${rpath}riscv32-unknown-elf-objdump -D ../testspace/test.om > ../testspace/test.dump

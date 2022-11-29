#!/bin/sh
# build testcase
./build_test.sh $@
# copy test input
if [ -f ../testcase/fpga/$@.in ]; then cp ../testcase/fpga/$@.in ../testspace/test.in; fi
# copy test output
if [ -f ../testcase/fpga/$@.ans ]; then cp ../testcase/fpga/$@.ans ../testspace/test.ans; fi
# add your own test script here
# Example: assuming serial port on /dev/ttyUSB1
../fpga/build.sh
../fpga/run.sh ../testspace/test.bin ../testspace/test.in /dev/ttyUSB1 -I
#./ctrl/run.sh ./test/test.bin ./test/test.in /dev/ttyUSB1 -T > ./test/test.out
#if [ -f ./test/test.ans ]; then diff ./test/test.ans ./test/test.out; fi

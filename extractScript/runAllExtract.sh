#!/bin/sh

# This script exports the test data into files in ../data-files/export/global

dataDir=../test-files

srcDir=`pwd`

cd $dataDir

mkdir -p import
mkdir -p export/linux
mkdir -p export/win32
mkdir -p export/solaris
mkdir -p export/darwin
mkdir -p export/sinixz

# make some fix to a date

isql li_ltcs.gdb -i $srcDir/fix_it.sql
isql so_ltcs.gdb -i $srcDir/fix_it.sql
isql da_ltcs.gdb -i $srcDir/fix_it.sql
isql nt_ltcs.gdb -i $srcDir/fix_it.sql
isql sz_ltcs.gdb -i $srcDir/fix_it.sql
isql gtcs.gdb -i $srcDir/fix_it.sql


# export the data 
$srcDir/dump_gtcs.pl gtcs.gdb ./export/global/
$srcDir/dump_xx_ltcs.pl li_ltcs.gdb ./export/linux/
$srcDir/dump_xx_ltcs.pl nt_ltcs.gdb ./export/win32/
$srcDir/dump_xx_ltcs.pl so_ltcs.gdb ./export/solaris/
$srcDir/dump_xx_ltcs.pl da_ltcs.gdb ./export/darwin/
$srcDir/dump_xx_ltcs.pl sz_ltcs.gdb ./export/sinixz/

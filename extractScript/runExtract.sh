#!/bin/sh

# This script exports the test data into files in ../data-files/export/global

dataDir=../test-files

srcDir=`pwd`

cd $dataDir

mkdir -p import
mkdir -p export/global

# make some fix to a date

isql gtcs.gdb -i $srcDir/fix_it.sql


# export the data 
$srcDir/dump_gtcs.pl

#!/bin/sh

echo "Warning I have run the export script - and for completeness put"
echo" this together - but I have not really run it in earnest"
echo "MOD 27-July-2001"

# This script builds a new TCS database file in ../data-files/import 
# from ../data-files/export/global

dataDir=../test-files

srcDir=`pwd`

cd $dataDir

mkdir -p import


# create empty database

gdef -r $srcDir/gtcs.gdl


# import all tables from ./export/global

IMPDIR='./export/global/'
  for TABLE in `ls $IMPDIR*.csv`
  do
    echo Importing $TABLE
    $srcDir/import_gtcs.pl $TABLE
  done

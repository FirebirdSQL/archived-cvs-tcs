#!/bin/sh

# Copyright whatever... 

# This script is a real simple hack to get it going, it probably
# won't work for you, but it's simple enough that you should be
# able to follow the commands along manually

# There is also more detailed documentation in tcs/doc
# and you might want to check out interbase/firebird/fsg/TCS for
# some additonal scripts (that is the one in the interbase tree 
# not the TCS tree) 
# MOD 27-July-2001

#First I had to build the tcs programs tcs isc_diff drop_gds
# (there is a readme there for other platforms)

# I also hand edited a script file tcs/scripts/runtcs.fb2 which does a
# cd before connecting to isc4.gdb (it only does this because I ain't 
# allowing it to run via inetd or superserver currently)


(cd tcs/tcs; make -f makefile.linux tcs)   
(cd tcs/diffs; make -f makefile.linux isc_diff)
(cd tcs/drop_gdb; make -f makefile.linux)
(cd tcs/mu; make -f makefile.linux)


# create scripts bin dire and move executables to it

destDir=tcs/scripts/bin

mkdir -p $destDir

cp tcs/diffs/isc_diff  $destDir
cp tcs/tcs/tcs   $destDir
cp tcs/drop_gdb/drop_gdb  $destDir

cp tcs/mu/mu $destDir
cp tcs/mu/libmu.a $destDir
cp tcs/mu/client_lib.o $destDir


# restore the databases

IBBin=/opt/interbase/bin

cd test-dbs

for i in *gbk
  do
    NAME=${i##*/}
    NAME=${NAME%.*}
    newName="$NAME.gdb"

    echo "Restoring $newName from $i"
#    $IBBin/gbak -c -user SYSDBA -password masterkey $i ../test-files/$newName
    $IBBin/gbak -R -user SYSDBA -password masterkey $i ../test-files/$newName
  done

cd ..


# make a link from scripts directory to actual data called data.

ln -s ../../test-files tcs/scripts/tests



echo "To run cd tcs/scripts and ./runtcs or ./runtcs.fb2"


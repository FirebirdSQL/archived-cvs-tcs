
# The contents of this file are subject to the InterBase Public License
# Version 1.0 (the "License"); you may not use this file except in
# compliance with the License.
#
# You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.  The Original Code was created by Inprise
# Corporation and its predecessors.
#
# Portions created by Inprise Corporation are Copyright (C) Inprise
# Corporation. All Rights Reserved.
#
# Contributor(s): ______________________________________.

if [ -f expand.sed ]
then
  rm -f expand.sed
fi

echo 's?\"employee.gdb\"?\"'${CLIENT_TESTBED}'/employee.gdb\"?g' >> expand.sed
echo 's?\"employe2.gdb\"?\"'${CLIENT_TESTBED}'/employe2.gdb\"?g' >> expand.sed
echo 's?\"new.gdb\"?\"'${CLIENT_TESTBED}'/new.gdb\"?g' >> expand.sed

if [ $1 ]
then
  Echo "Setting EXAMPLEDIR to $1"
  EXAMPLEDIR=$1
else
  EXAMPLEDIR=$TCSDRIVE/interbase/examples
fi

echo "Expanding $EXAMPLEDIR to ${CLIENT_TESTBED}"

for DIRECTORY in $EXAMPLEDIR/* 
do
  for FILE in $DIRECTORY/*.*
  do
    sed -f expand.sed ${FILE} > $TEMPDIR/sed.TMP 2> 1.tmp
    if [ -s $TEMPDIR/sed.TMP ]
    then 
      cp $TEMPDIR/sed.TMP ${FILE}
      rm $TEMPDIR/sed.TMP
    fi
  done
done

if [ -f expand.sed ]
then
  rm -f expand.sed
fi

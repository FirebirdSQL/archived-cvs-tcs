#!/usr/bin/perl -w
##$Id$
# Import_gtcs.pl - read a symbol-separated ASCII file of data
#   and insert it into an InterBase database very very quickly
#   using IBPerl.
#
#   The input file must be in the form:
#     TABLENAME
#     FIELD1;FIELD2;FIELD3;...
#     VALUE1;VALUE2;VALUE3;...
#     VALUE1;VALUE2;VALUE3;...
#     ...
#
# Copyright 2000 Bill Karwin
#
# Changed a bit to be used for the test control system
# 2000 FSG
# 
# This assumes that there is a new (empty) gtcs.gdb in ./import
# (create it with: gdef gtcs.gdl)
# and that the tests, comments etc. reside in ./export/global
# you may change this at your need.

use strict; 
use IBPerl;
use Carp;

my ($db, $tr, $st);
my ($line, $table, @fields, $sql);
my ($i,$Field, @data);

print "Connect... ";
$db = new IBPerl::Connection(
	Path=>'gtcs.gdb',
	User=>'sysdba',
	Password=>'masterkey',
	Dialect=>3
    );
croak "$0: $db->{Error}\n" if ($db->{Handle} < 0);
print "ok\n";

print "Start transaction... ";
$tr = new IBPerl::Transaction(Database=>$db);
croak "$0: $tr->{Error}\n" if ($tr->{Handle} < 0);
print "ok\n";

$table = <>; chop($table);

$line = <>; chop($line);
@fields = (split(';', $line));
$sql = "INSERT INTO $table (" .
    join(',', @fields) .
    ') VALUES (' .
    ('?, 'x$#fields) .
    "?)";
#print $sql;

$st = new IBPerl::Statement(Transaction=>$tr, SQL=>$sql);
croak "$0: $st->{Error}, SQL =\n$sql\n" if ($st->{Handle} < 0);

while (<>)
{   
    chop;
    @data=split(/;/,$_);
    $i=0;
    foreach $Field (@data)
    {
      if (substr($Field,0,1) eq '@') 
      {
         open(FILEHANDLE,"./export/global/$Field");
         sysread(FILEHANDLE, $data[$i], 1000000);
       #  @data[$i]='BLOB';
      }     

      if ($Field eq '<null>')
      {
         $data[$i]=undef;
      }
      ++$i;
    } 
    $i=@fields;
    while ($i > @data)
    {
       @data=(@data,undef);
    }
    if ($st->execute( @data ) < 0)
    {
	carp "$0: $st->{Error} on input line $. of $ARGV.\n";
    }
}

$tr->commit();
$db->disconnect();
print "Done!\n";

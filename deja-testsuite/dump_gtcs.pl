#!/usr/bin/perl  
#$Id$
# dump_gtcs.pl - dumps data from gtcs.gdb to disk.
#
# Copyright 2000 FSG
# This is based on the example select.pl
# from Bill Karwin.
# As I have no idea how to write perl programs
# this may be ugly, buggy or whatsoever
# tested with IBPerl-0.8p3
#
# use fix_it.sql before you try to export from
# an original gtcs.gdb, otherwise
# import_gtcs won't work as expected
#
#

use IBPerl;
use strict;

%main::meta_series;

my $DBPATH='./test-dbs/gtcs.gdb';
my $EXPORTPATH='./export/global/';
my $OUTPATH='./export/output/';

$DBPATH = $ARGV[0] if (defined($ARGV[0]));
$EXPORTPATH = $ARGV[1] if (defined($ARGV[1]));
$OUTPATH = $ARGV[2] if (defined($ARGV[2]));

# Connect to database

my $db = new IBPerl::Connection(
         Path=>"$DBPATH",
         User=>'sysdba',
         Password=>'masterkey');

if ($db->{'Handle'} < 0)
{
    print STDERR "Connection Error:\n$db->{'Error'}\n";
    print "not ok\n"; # Test 1
    exit 1;
}



######################################################################
# Start transaction

    my $tr = new IBPerl::Transaction(Database=>$db);
    if ($tr->{'Handle'} < 0)
    {
	print STDERR "Transaction Error:\n$tr->{'Error'}\n";
	print "not ok\n"; # Test 2
	exit 1;
    }

######################################################################
# What to dump
#
#       my  @tables = qw(AUDIT BOILER_PLATE CATEGORIES ENV FAILURES INIT KNOWN_FAILURES META_SERIES 
#                        META_SERIES_COMMENT NOTES PYXIS$FORMS QLI$PROCEDURES SERIES SERIES_COMMENT
#                        TESTS TIMES WORKLIST);
       
# Dump only the populated tables
       

       my  @tables = qw(INIT NOTES META_SERIES SERIES SERIES_COMMENT TESTS BOILER_PLATE ENV);
       my $table ='';
       # create export directory
       mkdir("export",040755);      
       mkdir("export/global",040755); 

       process_meta_series($tr);

       foreach $table (@tables)
       { 
         #dumptable($table);
       }
       
######################################################################
# Commit

if ($tr->commit() < 0)
{
  print STDERR "Commit Error:\n$tr->{'Error'}\n";
  print "not ok\n"; # Test 7
  exit 1;
}

######################################################################
# Disconnect

if ($db->disconnect() < 0)
{
  print STDERR "Connection Error:\n$tr->{'Error'}\n";
  print "not ok\n"; # Test 8
  exit 1;
}

######################################################################
# Done

exit 0;

#end



#####################################################################
# Dump table  

sub dumptable {
    my @row;
    my $Fields;
    my $keyname='ERROR';
    my $outname;
    my $ret;
    my $i;
    my $count=0;
    my $first=1;
    my($table) =@_;
    my $query='SELECT * FROM ' . $table; 

    my $st = new IBPerl::Statement(Transaction=>$tr, SQL=>$query);
 
    if ($st->{'Handle'} < 0)
    {
      print STDERR "Statement Error:\n$st->{'Error'}\n";
      print "not ok\n"; # Test 3
      exit 1;
    }
 
    if ($st->execute() != 0)
    {
      print STDERR "Statement Error:\n$st->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }
    
     
    $outname= ">".$EXPORTPATH.$table.".csv";
    open(OUT,$outname) || die "can't create file $outname";
    print OUT "$table\n";
    print "Processing $table\n";  
    while (1)
    {
       $ret = $st->fetch(\@row);
       ++$count;
       last if ($ret == 100);
       if ($ret < 0)
       {
          print STDERR "Statement Error:\n$st->{'Error'}\n";
	  print "not ok\n" # Test 5
       }
       last if ($ret != 0);
       if ($first)
       { 
         #first fetch, so dump column headers
         $i=0;
         foreach $_ (@row) 
         {
           print OUT "\"$st->{Columns}[$i]\";";
           ++$i;  
          }
          print OUT "\n";
        }
        $i=0;
        $first=0;
        $Fields='';
        #print field values
        foreach $Fields (@row)
        {
           if ($st->{Nulls}[$i])
           {
             print OUT "<null>;";
           }
           else
           {
           if ($st->{Datatypes}[$i] eq 'BLOB')
           # Dump the blob to a file and print a reference
           {
             $outname= "@"."$table.$st->{Columns}[$i].$keyname.".$count.".blob";
             print OUT "$outname;"; 
             open (BLOB, ">".$EXPORTPATH.$outname);
             print BLOB $Fields;
             close(BLOB);
           }
           else
           {
           # print value
             if ($i==0)
             {
               # I use this to identify the blobs
               # assuming that the first field
               # contains a test_name, series_name or a similar
               # unique value.   
               $keyname=$Fields;
                
               #remove trailing spaces
               for ($keyname) 
               {
                   s/^\s+//;
                   s/\s+$//;
               }
             } 
             print OUT "$Fields;";
           }
           }
       ++$i;
       }
       $i=0;
       print OUT "\n";
      
    }
    if ($st->close == 0)
    {
    } 
    else 
    {
      print STDERR "Statement Error:\n$st->{'Error'}\n";
      print "not ok\n"; # Test 6
      exit 1;
    }
    close(FILEHANDLE);
}

#################################################################
#
#

sub process_meta_series
{
    my $tr = shift;

    my $stmt = new IBPerl::Statement( Transaction => $tr, SQL => "select * from meta_series order by meta_series_name, sequence" );
    my %row;
    my $ret;
    my $meta;
    my $test;
    my $arrRef;

    if ($stmt->{'Handle'} < 0)
    {
      print STDERR "Statement Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 3
      exit 1;
    }
 
    if ($stmt->execute() != 0)
    {
      print STDERR "Statement Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }
    
    while (100 != ($ret = $stmt->fetch(\%row)))
    {
        if ($ret < 0)
        {
            print STDERR "Statement Error:\n$stmt->{'Error'}\n";
            print "not ok\n"; # Test 5
            last;
        }

        $meta = $row{META_SERIES_NAME};
        chomp $meta;
        $meta =~ s/ +$//g;
        if ( !defined($main::meta_series{$meta}) )
        {
            $main::meta_series{$meta} = [];
        }
        $arrRef = $main::meta_series{$meta};
        $$arrRef[$#$arrRef+1] = $row{SERIES_NAME};
        $main::meta_series{$meta} = $arrRef;
    }
    $stmt->close;

    foreach $meta (keys(%main::meta_series))
    {
        $arrRef = $main::meta_series{$meta};
        open(OUT, "> $EXPORTPATH$meta.meta");
        foreach $test (@$arrRef)
        {
            chomp $test;
            $test =~ s/ +$//g;
            print OUT "$test\n";
            process_series($test, $tr);
        }
        close(OUT);
    }
}

#################################################################
#
#

sub process_series
{
    my $series = shift;
    my $tr = shift;

    my $stmt = new IBPerl::Statement( Transaction => $tr, SQL => "select * from series where series_name = '$series' order by sequence" );
    my %row;
    my $ret;
    my $meta;
    my $test;
    my $arrRef;

    if ($stmt->{'Handle'} < 0)
    {
      print STDERR "Statement Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 3
      exit 1;
    }
 
    if ($stmt->execute($series) != 0)
    {
      print STDERR "Statement Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }
    
    system "mkdir -p $EXPORTPATH$series";
    system "mkdir -p $OUTPATH$series";
    open(SERIES_OUT, "> $EXPORTPATH$series/$series.series") || die ("Failed to open $EXPORTPATH$series.series");
    while (100 != ($ret = $stmt->fetch(\%row)))
    {
        if ($ret < 0)
        {
            print STDERR "Statement Error:\n$stmt->{'Error'}\n";
            print "not ok\n"; # Test 5
            last;
        }

        $test = $row{TEST_NAME};
        chomp $test;
        $test =~ s/ +$//g;
        print SERIES_OUT "$test\n";
        extract_test_script($test, $series, $tr);
        extract_test_output($test, $series, $tr);
    }
    $stmt->close;
    close(SERIES_OUT);
}

sub extract_test_script
{
    my $test = shift;
    my $series = shift;
    my $tr = shift;

    my $stmt = new IBPerl::Statement( Transaction => $tr, SQL => "select * from tests where test_name = '$test' and NO_RUN_FLAG is NULL order by VERSION desc" );
    my %row;
    my $ret;

    if ($stmt->{'Handle'} < 0)
    {
      print STDERR "Statement Error 1:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 3
      exit 1;
    }
 
    if ($stmt->execute() != 0)
    {
      print STDERR "Statement Error 2:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }

    if (0 == ($ret = $stmt->fetch(\%row)))
    {
        if ($ret < 0)
        {
            print STDERR "Statement Error 3:\n$stmt->{'Error'}\n";
            print "not ok\n"; # Test 5
            last;
        }

        open (TEST_SCRIPT, "> $EXPORTPATH$series/$test.script");
        print TEST_SCRIPT $row{SCRIPT};
        close(TEST_SCRIPT);
    }
    if ($ret != 0 && $ret != 100)
    {
      print STDERR "Fetch Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }

    $stmt->close;
}

sub extract_test_output
{
    my $test = shift;
    my $series = shift;
    my $tr = shift;

    my $stmt = new IBPerl::Statement( Transaction => $tr, SQL => "select * from init where test_name = '$test' order by VERSION desc" );
    my %row;
    my $ret;

    if ($stmt->{'Handle'} < 0)
    {
      print STDERR "Statement Error 1:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 3
      exit 1;
    }
 
    if ($stmt->execute() != 0)
    {
      print STDERR "Statement Error 2:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }

    if (0 == ($ret = $stmt->fetch(\%row)))
    {
        if ($ret < 0)
        {
            print STDERR "Statement Error 3:\n$stmt->{'Error'}\n";
            print "not ok\n"; # Test 5
            last;
        }

        open (TEST_OUTPUT, "> $OUTPATH$series/$test.output");
        print TEST_SCRIPT $row{OUTPUT};
        close(TEST_OUTPUT);
    }
    if ($ret != 0 && $ret != 100)
    {
      print STDERR "Fetch Error:\n$stmt->{'Error'}\n";
      print "not ok\n"; # Test 4
      exit 1;
    }

    $stmt->close;
}

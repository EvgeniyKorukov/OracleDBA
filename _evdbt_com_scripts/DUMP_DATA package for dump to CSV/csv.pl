#!/usr/bin/perl

# Run under Oracle Perl for DBI.
BEGIN {
    die "ORACLE_HOME not set\n" unless $ENV{ORACLE_HOME};
    unless ($ENV{OrAcLePeRl}) {
       $ENV{OrAcLePeRl} = "$ENV{ORACLE_HOME}/perl";
       $ENV{PERL5LIB} = "$ENV{PERL5LIB}:$ENV{OrAcLePeRl}/lib:$ENV{OrAcLePeRl}/lib/site_perl";
       $ENV{LD_LIBRARY_PATH} = "$ENV{LD_LIBRARY_PATH}:$ENV{ORACLE_HOME}/lib32:$ENV{ORACLE_HOME}/lib";
       exec "$ENV{OrAcLePeRl}/bin/perl", $0, @ARGV;
    }
}

use strict;
use warnings;
use DBI;

# obtain values from command-line arguments...
die "Usage: \"perl $0 <tablespace-name> <table-owner> <table-name>\"" unless $#ARGV == 2;

my $oraSid = "$ENV{ORACLE_SID}";
my $tmp_oraSid = "";
my $tmp_username = "";
my $username = $tmp_username;
my $tmp_password = "";
my $password = $tmp_password;

# find username/password entry in $HOME/.unpwd (line format = "username/password@TNS-entry")
my $unpwd = "$ENV{HOME}/.unpwd";
open UNPWD, "<", "$unpwd" or die "Could not find Oracle password file \"$unpwd\"";
LOOP:	{
	while (<UNPWD>) {
		chomp($_);
		($tmp_username, $tmp_password, $tmp_oraSid) = m{^\s*(\S+)\s*/\s*(\S+)\s*@\s*(\S+)\s*$}x or die "Could not parse line in Oracle password file \"$unpwd\"";
		if ($tmp_oraSid eq $oraSid) {
			$username = $tmp_username;
			$password = $tmp_password;
			last LOOP;
		}
	}
}
die "Could not find entry for database \"$oraSid\" in Oracle password file \"$unpwd\"" unless $username;
close(UNPWD);

# connect to the database...
my $dbh = DBI->connect("dbi:Oracle:$ENV{ORACLE_SID}", $username, $password) or die;

# query using the DUMP_DATA.CSV pipelined table function...
my $sql = qq{ SELECT TXT FROM TABLE(AUTOMATE.DUMP_DATA.CSV(?, ?, ?)) };
my $sth = $dbh->prepare($sql);
$sth->execute($ARGV[0], $ARGV[1], $ARGV[2]);

my($txt);
$sth->bind_columns(\$txt);

while( $txt = $sth->fetchrow_array() ) {
    print "$txt\n";
}

$sth->finish();

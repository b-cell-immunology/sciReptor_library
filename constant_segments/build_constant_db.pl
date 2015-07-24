#!/usr/bin/perl

=head1 NAME

build_constant_db

=head1 SYNOPSIS

build_constant_db.pl

=head1 ARGUMENTS 



=head1 DESCRIPTION



=head1 HISTORY

=cut

use DBI;
use strict;
use warnings;
use Getopt::Long;
use Bio::SeqIO;

my $lib_input = "";
my $species = "";
my $fasta_file = "";
my $mysql_group = "";

&GetOptions(
	"mysql_group=s"	=> \$mysql_group,
	"lib=s" => \$lib_input,
	"sp=s"	=> \$species,
	"fasta=s"	=>\$fasta_file,
);

# Set up logging
# prefix for logging, telling where log comes from
my $log_prefix = "[build_constant_db] [LOG] ";
my $error_prefix = "[build_constant_db] [ERR] ";

# get library database scheme, exit if not given
my $library_scheme;
if ($lib_input) {$library_scheme = $lib_input;}
else {die "No library specified with -lib argument.";}

# Get species and check if its meaningfull
unless ($species eq "human" || $species eq "mouse") {
  if ($species) {
    die "$error_prefix Species $species is not supported. Only human or mouse.\n";
  }
  else { die "$error_prefix Missing species definition in command line argument -sp." }
}

die "No mysql_group as in ~/.my.cnf file specified with -mysql_group argument." unless $mysql_group;

# constant database fasta file is defined in the config
my $const_fasta = $fasta_file; 


# Get database handle from bcelldb_init.
# This does not work if there is no database defined in the config file.
my $dsn="DBI:mysql:$library_scheme;mysql_read_default_file=~/.my.cnf;mysql_read_default_group=$mysql_group;";
my $dbh = DBI->connect($dsn,undef,undef,{PrintError=>1});


# Insert Information from fasta file

my $insert_seg_statement = "INSERT INTO $library_scheme.constant_library (species_id, name, locus, sequence) values (?,?,?,?)";
my $ins_seq_query = $dbh->prepare($insert_seg_statement);


# open and read fasta file

my $fasta_in = Bio::SeqIO->new(-file => $const_fasta, -format => 'fasta') or die "$error_prefix could not open $const_fasta";

while (my $seq = $fasta_in->next_seq()) {
  my $seq_id =  $seq->id;
  
  if ($seq_id =~ m/NCBI/) {
    ($seq_id, my $id_rest) = split(/:/, $seq_id, 2);
  }
  # IMGT formatting
  elsif ($seq_id =~ m/\|/) {
    (my $id_rest1, $seq_id, my $id_rest2) = split(/\|/, $seq_id, 23);
  }
  # for the meantime we do not implement parsing other formats
  # if necessary, insert additional parser here
  else {
      print "$log_prefix Fasta identifers in $const_fasta could not be parsed to extract segment name like for standard NCBI or IMGT format. Taking fasta identifier as segment name.\n";
  }
  print "$log_prefix $seq_id was processed.\n";
  my $locus = "";
  # parse locus from seq_id
  if ($seq_id =~ m/[Hh]/) {
    $locus = "H";
  }
  elsif ($seq_id =~ m/[Ll]/) {
    $locus = "L";
  }
  elsif ($seq_id =~ m/[Kk]/) {
    $locus = "K";
  }
  else {print "$log_prefix Fasta identifer $seq_id could not be parsed to extract locus.\n";}
  
  $ins_seq_query->execute($species, $seq_id, $locus, $seq -> seq);
}


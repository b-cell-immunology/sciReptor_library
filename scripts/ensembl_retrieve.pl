#!/usr/bin/perl
use warnings;
use strict;
use LWP::Simple;
use Getopt::Long;

# This script reads a CSV input file and then retrieves genomic sequences from the ENSEMBL database using the given coordinates

my $config_ensembl_address = "www.ensembl.org";
my $config_field_separator = ",";

my %static_lut_assemblies = ( 
	"NCBIm37" => "Mus musculus",
	"NCBIm38" => "Mus musculus"
);

my $query_species = '';
my $query_assembly = '';
my $query_chromosome = '';
my $option_show_help = '';

GetOptions (
	'species=s' => \$query_species,
	'assembly=s' => \$query_assembly,
	'chromosome=i' => \$query_chromosome,
	'separator=s' => \$config_field_separator,
	'help' => \$option_show_help
);

if ($option_show_help) {
	print "Usage: ensembl_retrieve.pl [options] csv-file\n";
	print "Retrieves DNA sequence information from the ENSEMBL database, according to the positions and orientation\n";
	print "given in csv-file. If no filename is provided, standard input is used.\n\n";
	print "Options:\n   --species      Binomial designation of the species to retrieve from e.g. --species=\"Mus musculus\"\n";
	print "   --assembly     Designator of the assembly. Will overwrite \"species\" option if defined in internal script lookup table\n";
	print "   --separator    Alternative field separator for CSV file, default is \",\"\n";
	exit 1;
}

if (($query_assembly) && (exists $static_lut_assemblies{$query_assembly})) {
	if ($query_species) {
		printf STDERR "[ensembl_retrieve.pl][WARNING] Replacing --species option with predefined value for assembly \"%s\" => \"%s\""
			, $query_assembly, $static_lut_assemblies{$query_assembly};
	}
	$query_species = $static_lut_assemblies{$query_assembly};
}

if ((! $query_species) || ($query_species !~ /[A-Z][a-z]+\ [a-z]+/)) {
	printf STDERR "[ensembl_retrieve.pl][FATAL] \"--species\" option missing or invalid! Required input is the correct binomial name (including capitalization).\n";
	exit 1;
}
$query_species =~ s/ /_/g;

while (my $query_input_line = <>) {
	chomp($query_input_line);
	my ($query_name, $query_chromosome, $query_start, $query_end, $query_ori) = split /${config_field_separator}/, $query_input_line;
	$query_name =~ s/\"//g;

	if (($query_chromosome =~ /[0-9]{1,2}/) && ($query_start =~ /[0-9]+/) && ($query_end =~ /[0-9]+/) && ($query_ori =~ /-?1/)) {
		my $tmp_query_string = sprintf "http://%s/%s/Export/Output/Location?db=core;output=fasta;r=%i:%i-%i;strand=%i;genomic=unmasked;_format=Text",
			$config_ensembl_address, $query_species, $query_chromosome, $query_start, $query_end, $query_ori;

		if (my $tmp_get_data = get($tmp_query_string)) {
			$tmp_get_data =~ s/[\x0A]+$/\x0A/; # Remove trailing newlines, but leave one so that ''split'' in the next line can work.
			my @tmp_query_response = split /\x0D\x0A/, $tmp_get_data;
			printf ">%s:%s:%i:%i:%i:%i\n", $query_name, $query_assembly, $query_chromosome, $query_start, $query_end, $query_ori;
			foreach (1..$#tmp_query_response) {
				print "$tmp_query_response[$_]\n";
			}
			print "\n";
		} else {
			print STDERR "[ensembl_retrieve.pl][ERROR] Get failed for \"$tmp_query_string\"\n";
		}
	} else {
 		printf STDERR "[ensembl_retrieve.pl][WARNING] Ignoring line %i of file %s with chromosome \"%s\", start \"%s\", end \"%s\" and ori \"%s\"\n",
			$., $ARGV, $query_chromosome, $query_start, $query_end, $query_ori;
	}
}

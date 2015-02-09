#!/usr/bin/env perl

=head1 NAME

nodelist.pl - turn XML text metadata into a simple table

=head1 SYNOPSIS

nodelist.pl [options]

=head1 DESCRIPTION

Reads in metadata from Tesserae and produces a table of text "nodes" that
gets used as input for F<all_la_verse.pl> and for F<process_tess_an.R>.
In addition to the author and date for each text, it also calculates several
features that might be interesting as potential factors on the score,
including number of tokens, stems, lines, and phrases, as well as type-token
ratios for both words and stems.

=head1 OPTIONS AND ARGUMENTS

=over

=item --authors I<FILE>

The input file giving author information. Default is 
"/vagrant/metadata/authors.xml", taken from the "metadata_db" branch of my
Tesserae repo.

=item --texts I<FILE>

Second input file, giving text information. Default is 
"/vagrant/metadata/texts.xml", also from "metadata_db".

==item --output I<FILE>

Name for the resulting table. Default is "/vagrant/metadata/index_text.txt".
Note that F<all_la_verse.pl> and F<process_tess_an.R> need this, so you'll
have to make changes accordingly if you specify something else here.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=over

=item F<all_la_verse.pl>

=item F<process_tess_an.R>

=back

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0. The contents of this file
are subject to the University at Buffalo Public License Version 1.0 (the
"License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is nodelist.pl.

The Initial Developer of the Original Code is Research Foundation of State
University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research
Foundation of State University of New York, on behalf of University at
Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 (the "GPL"), or the GNU
Lesser General Public License Version 2.1 (the "LGPL"), in which case the
provisions of the GPL or the LGPL are applicable instead of those above. If
you wish to allow use of your version of this file only under the terms of
either the GPL or the LGPL, and not to allow others to use your version of
this file under the terms of the UBPL, indicate your decision by deleting
the provisions above and replace them with the notice and other provisions
required by the GPL or the LGPL. If you do not delete the provisions above,
a recipient may use your version of this file under the terms of any one of
the UBPL, the GPL or the LGPL.

=cut

use strict;
use warnings;

#
# Read configuration file
#

# modules necessary to read config file

use Cwd qw/abs_path/;
use File::Spec::Functions;
use FindBin qw/$Bin/;

# read config before executing anything else

my $lib;

BEGIN {

	# look for configuration file
	
	$lib = $Bin;
	
	my $oldlib = $lib;
	
	my $pointer;
			
	while (1) {

		$pointer = catfile($lib, '.tesserae.conf');
	
		if (-r $pointer) {
		
			open (FH, $pointer) or die "can't open $pointer: $!";
			
			$lib = <FH>;
			
			chomp $lib;
			
			last;
		}
									
		$lib = abs_path(catdir($lib, '..'));
		
		if (-d $lib and $lib ne $oldlib) {
		
			$oldlib = $lib;			
			
			next;
		}
		
		die "can't find .tesserae.conf!\n";
	}
	
	$lib = catdir($lib, 'TessPerl');
}

# load Tesserae-specific modules

use lib $lib;
use Tesserae;
use EasyProgressBar;

# modules to read cmd-line options and print usage

use Getopt::Long;
use Pod::Usage;

# load additional modules necessary for this script

use XML::LibXML;
use Storable;

# initialize some variables

my $file_auth = "/vagrant/metadata/authors.xml";
my $file_text = "/vagrant/metadata/texts.xml";
my $file_out = "/vagrant/metadata/index_text.txt";
my $help = 0;

# get user options

GetOptions(
   "authors=s" => \$file_auth,
   "texts=s" => \$file_text,
   "output=s" => \$file_out,
   "help"  => \$help
);

# print usage if the user needs help
	
if ($help) {

   pod2usage(1);
}

# load metadata
# date for each text is publication date, if there is one,
# otherwise the author's date of death

my $ref_auth_date = load_auth($file_auth);
my $ref_meta = load_text($file_text, $ref_auth_date);
my %meta = %{load_tess($ref_meta)};

# sort texts chronologically

my @texts = sort {$meta{$a}->{date} <=> $meta{$b}->{date}} sort keys %meta;

# retrieve metadata / calc features for each text in turn;
# write the index. give each text a numeric id.

open (my $fh, ">:utf8", $file_out) or die "Can't write $file_out: $!";

my @fields = qw/auth date tokens stems lines phrases ttr_w ttr_s/;

print $fh join("\t", "id", "label", @fields) . "\n";

for my $i (0..$#texts) {
   my $text_id = $texts[$i];
   my %m = %{$meta{$text_id}};
   my @row = map {$_ or "NA"} @m{@fields};
   
   print $fh join("\t", $i, $text_id, @row);
   print $fh "\n";
}

close($fh);

#
# subroutines
#

sub load_auth {
   my $file = shift;
   
   print STDERR "Reading $file\n";
   
   my %auth_date;
   
   my $doc = XML::LibXML->load_xml(location=>$file);
   
   for my $auth_node ($doc->findnodes("//TessAuthor")) {
      my $id = $auth_node->getAttribute("id");
      my $date = $auth_node->findvalue("Death");
      
      if (defined $date and $date =~ /[0-9]/) {
         $auth_date{$id} = $date;
      }
   }
   
   return \%auth_date;
}

sub load_text {
   my ($file, $ref_auth_date) = @_;
   
   print STDERR "Reading $file\n";
   
   my %auth_date = %$ref_auth_date;
   
   my %meta;
   
   my $doc = XML::LibXML->load_xml(location=>$file);
   
   for my $text_node ($doc->findnodes("//TessDocument")) {
      my $id = $text_node->getAttribute("id");
      my $auth = $text_node->findvalue("Author");
      my $pub = $text_node->findvalue("PubDate");
      my $mode = $text_node->findvalue("Prose");
      
      next if $mode;
      
      unless (defined $pub and $pub =~ /[0-9]/) {
         $pub = $auth_date{$auth};
      }
      
      $meta{$id} = {auth => $auth, date => $pub};
   }
   
   return \%meta; 
}

sub load_tess {
   my $ref = shift;
   
   print STDERR "Extracting Tesserae data\n";
   
   my %meta = %$ref;
   
   my $pm = ProgressBar->new(scalar(keys %meta));
      
   for my $text_id (keys %meta) {
      my $base = catfile($fs{data}, "v3", "la", $text_id, $text_id);

      my ($tokens, $ttr_w) = wc($base . ".freq_stop_word");
      my ($stems, $ttr_s) = wc($base . ".freq_stop_stem");
      
      my $lines = scalar(@{retrieve($base . ".line")});
      my $phrases = scalar(@{retrieve($base . ".phrase")});
      
      $meta{$text_id} = { %{$meta{$text_id}},
        tokens => $tokens,
        stems => $stems,
        lines => $lines,
        phrases => $phrases,
        ttr_w => $ttr_w,
        ttr_s => $ttr_s 
      };
      
      $pm->advance;
   }
   
   return \%meta;
}

sub wc {
   my $file = shift;
   
   my $count;
   my $ttr;
   
   open (my $fh, "<:utf8", $file) or die "$!";
   
   my $head = <$fh>;
   $head =~ /count: (\d+)/;
   $count = $1;
   
   while (my $line = <$fh>) {
      $ttr ++;
   }
   
   $ttr /= $count;
   
   close $fh;
   
   return ($count, $ttr);
}
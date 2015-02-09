#!/usr/bin/env perl

=head1 NAME

metadata_export_text.pl - extract metadata from Tesserae texts

=head1 SYNOPSIS

metadata_export_text.pl [options]

=head1 DESCRIPTION

This is the script I used to get the most recent metadata for our corpus.
It's meant to be used with the "metadata_db" branch of my Tesserae GitHub
repo, which has switched from storing metadata centrally to including it
in the headers of the individual texts (now in XML format).

I've already run this, and the results are bundled with the present code
under "metadata/authors.xml" and "metadata/texts.xml".  This set of 
experiments is designed to use the master branch of the Tesserae repo,
anyway, and so this script won't work here. I'm only bundling it with this 
project rather than with "metadata_db" because for the moment this is all 
I'm using it for.

If you really want to use this, get the "metadata_db" branch working 
somewhere else, then copy this file to Tesserae's scripts/ directory and
run it there, after having installed the corpus.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0. The contents of this file
are subject to the University at Buffalo Public License Version 1.0 (the
"License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is metadata_export_text.pl.

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

# initialize some variables

my $help = 0;

# get user options

GetOptions(
	'help'  => \$help
);

# print usage if the user needs help
	
if ($help) {

	pod2usage(1);
}

# init output document

my $doc_out = XML::LibXML::Document->createDocument("1.0", "UTF-8");
my $corpus = $doc_out->createElement("Corpus");
$doc_out->setDocumentElement($corpus);

# load old metadata
my %pub;
{
   my $old_meta_file = catfile($fs{data}, "common", "metadata", "Texts.txt");
   
   open (my $fh, "<:utf8", $old_meta_file);
   
   <$fh>;
   
   while (my $line = <$fh>) {
      chomp $line;
      my @field = split(/\t/, $line);
      
      for (4,5,6) {
         next unless (defined $field[$_] and $field[$_] ne "");
      }
      
      my $pub_date = $doc_out->createElement("PubDate");
      $pub_date->setAttribute("cert", $field[5]);
      $pub_date->appendText($field[4]);
      
      $pub{$field[6]} = $pub_date;
   }
   
   close $fh;
}

# get textlist

my @texts = @{Tesserae::metadata_textlist({"Lang" => "la", "Prose" => "1"})};

for my $text_id (@texts) {
   
   my $file = catfile($fs{text}, "xml", $text_id . ".xml");
   
   my $doc_in = XML::LibXML->load_xml(location=>$file);
   
   my $this_text = $doc_in->find("//Metadata")->get_node(1);
   $this_text->setNodeName("TessDocument");
   $this_text->setAttribute("id", $text_id);

   if (defined $pub{$text_id}) {
      $this_text->appendChild($pub{$text_id});
   }
   
   $corpus->appendChild($this_text);
}

$doc_out->toFile("texts.xml", 2);
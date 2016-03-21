#!/usr/bin/env perl

=head1 NAME

all_la_verse.pl - batch search of Latin verse corpus

=head1 SYNOPSIS

all_la_verse.pl [options]

=head1 DESCRIPTION

This script does pairwise searches on the entire Latin verse corpus.
It's meant to be run inside a virtual machine as the basis for the 
"la_verse" experiment set. The scores for individual runs are extracted
using the ancillary script "extract_scores.pl". These scores will be used
as input for Neil Bernstein and Kyle Gervais' intertextual density work
as well as for Alex Nikolaev and Ali Farasat's network analysis.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--continue>

Resume a previously aborted batch run. In this mode, the list of tesserae
searches to perform will not be generated anew, but read from an existing
run index file. The output directory won't be cleaned, and any run that 
duplicates an existing session in the output directory will be skipped.

=item --texts I<FILE>

Index of texts to be searched, with metadata. This file is created by
F<nodelist.pl>. Default is "/vagrant/metadata/index_text.txt".

=item --runs I<FILE>

Name given to the index, created by the present script, of all Tesserae
searches to be performed. Each row of this file has the form
  run_id    source_id  target_id
where I<source_id> and I<target_id> correspond to the I<id> column of
the texts index specified as input above. The default name is 
"/vagrant/metadata/index_runs.txt"

=item --working I<DIR>

Path to working directory, where the completed tess searches store their
session data. NB This directory is entirely cleared before starting, 
unless the B<--continue> flag is set. Default value is 
"/home/vagrant/working". Note that while Tesserae session data is not
deleted when the program completes, it's stored in the vagrant home 
directory, not in the folder shared by the host, so its contents are
by default only visible from within the virtual machine. 

=item --parallel I<N>

The number of Tesserae searches to run in parallel. I've configured the
Vagrantfile to give the guest two cores; the default value here is likewise
2. In some cases, simultaneously running different searches on large texts 
was eating up the VM's RAM: to combat this I've increased the RAM in the
Vagrant file to 8GB and randomized the order of the searches so that you're
less likely to have, e.g. two searches on Ov. Met., but in a pinch you can
use --parallel 0 to ensure that only one search is run at a time. Or if you
have the resources for it, increase the number of RAM and cores and use a
higher value of I<N> to get things done faster.

=item B<--[no]shuffle>

Randomize the order in which the searches are performed. This decreases the
chances of running simultaneous searches on a big text (see above). On by
default; use B<--noshuffle> to have the searches performed in the order
in which they appear in the runs index (see above).

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=over

=item F<nodelist.pl>

=item F<extract_scores.pl>

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

The Original Code is all_la_verse.pl.

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

use File::Path qw/make_path remove_tree/;
use Parallel::ForkManager;
use XML::LibXML;

# initialize some variables

my $continue = 0;
my $tessroot = "/home/vagrant/tesserae";
my $file_runs = "/vagrant/metadata/index_run.txt";
my $file_texts = "/vagrant/metadata/index_text.txt";
my $dir_sessions = "/home/vagrant/working";
my $parallel = `. /vagrant/setup/tessrc; echo $TESSNCORES`;
my $shuffle = 1;
my $help = 0;

my %arg = (
   "--unit" => "line",
   "--feature" => "stem",
   "--stop" => "10",
   "--stbasis" => "both",
   "--score" => "stem",
   "--dist" => "5",
   "--dibasis" => "freq",
   "--cutoff" => "0"
);

# get user options

GetOptions(
   "continue" => \$continue,
   "texts" => \$file_texts,
   "runs" => \$file_runs,
   "working" => \$dir_sessions,
   "parallel=i" => \$parallel,
   "shuffle!" => \$shuffle,
   "help"  => \$help
);

# print usage if the user needs help
	
if ($help) {

   pod2usage(1);
}

# load corpus

my @corpus = @{load_corpus($file_texts)};

# create/clean output directories

unless ($continue) {
   remove_tree($dir_sessions);
   make_path($dir_sessions);
}

# organize all runs in a list to facilitate parallelization

my $ref_run = $continue ? load_runs($file_runs) : calc_runs($#corpus);
my $ndigit = ndigit($ref_run);
write_index($file_runs, $ref_run, $ndigit) unless $continue;
$ref_run = shuffle_runs($ref_run) if $shuffle;

#
# main loop
#

my $pm;
if ($parallel) {
   $pm = Parallel::ForkManager->new($parallel);
}

my @run = @$ref_run;

for my $i (0..$#run) {
   # fork
   
   if ($parallel) {
      $pm->start and next;
   }
   
   # params for this run

   my $source = $corpus[$run[$i]->{source}]{label};
   my $target = $corpus[$run[$i]->{target}]{label};

   my $name = sprintf("%0${ndigit}d", $run[$i]{id});

   # run tesserae search

   my $cmd = join(" ",
      "$tessroot/cgi-bin/read_table.pl",
      "--source" => $source,
      "--target" => $target,
      %arg,
      "--bin" => "$dir_sessions/$name",
      "--quiet"
   );

   print STDERR sprintf("[%d/%d] %s\n", $i+1, scalar(@run), $cmd);
   `$cmd`;

   $pm->finish if $parallel;
}
$pm->wait_all_children if $parallel;


#
# subroutines
#

sub load_corpus {
   my $file = shift;

   my @corpus;

   open (my $fh, "<:utf8", $file) or die "Can't read $file: $!";
   
   my %col = eval {
      my $head = <$fh>;
      chomp $head;
      my @col_name = split(/\t/, $head);
      
      map {$col_name[$_] => $_} (0..$#col_name);
   };
   
   while (my $line = <$fh>) {
      chomp $line;
      my @field = split(/\t/, $line);
      
      my $id = $field[$col{id}];
      
      for (qw/label auth date/) {
         $corpus[$field[$col{id}]]{$_} = $field[$col{$_}];
      }
   }
   close($fh);
   
   return \@corpus;
}

sub calc_runs {
   my $n = shift;
   
   my @run;
   
   for (my $t = 1; $t <= $n; $t++) {
      for (my $s = 0; $s < $t; $s++) {
         push @run, {
            id => scalar(@run),
            source => $s,
            target => $t
         };
      }
   }
   
   return \@run;
}

sub load_runs {
   my $file = shift;
   
   my @run;
   
   print STDERR "Continuing run list from $file\n";
   
   open (my $fh, "<:utf8", $file) or die "Can't read $file: $!";
   <$fh>;
   while (my $line = <$fh>) {
      chomp $line;
      
      my @field = split(/\t/, $line);
      push @run, {
         id => $field[0],
         source => $field[1],
         target => $field[2]
      };
   }
   close ($fh);
   
   @run = grep {! -d "$dir_sessions/$_->{id}"} @run;
   
   return \@run;
}

sub shuffle_runs {
   my $ref = shift;
   
   print "Shuffling run order\n";
   
   my @run = @$ref;
   
   @run = sort {rand() <=> rand()} @run;
   
   return \@run;
}

sub write_index {
   my ($file, $ref_run, $ndigit) = @_;
   my @run = @$ref_run;

   print STDERR "Writing $file\n";
   
   open (my $fh, ">:utf8", $file) or die "Can't write $file: $!";
   
   print $fh join("\t", qw/id source target/) . "\n";
   
   for my $i (0..$#run) {
      print $fh sprintf("%0${ndigit}i\t%i\t%i\n", $run[$i]->{id}, $run[$i]{source}, $run[$i]{target});
   }
   
   close ($fh);
}

sub ndigit {
   my $ref = shift;
   my @run = @$ref;
   
   my $max = 0;
   
   for (@run) {
      if ($_->{id} > $max) {
         $max = $_->{id};
      }
   }
   
   return length($max);
}

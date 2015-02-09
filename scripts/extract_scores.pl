#!/usr/bin/env perl

=head1 NAME

extract_scores.pl - get scores only from Tess sessions

=head1 SYNOPSIS

extract_scores.pl [options]

=head1 DESCRIPTION

This script reads through the "working" directory full of Tesserae session
data created by F<all_la_verse.pl> and produces, for each run, a text file
containing only the scores for all of the hits. These can then be further
digested using, e.g., F<process_tess_an.R>.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--continue>

Pick up where a previous run left off. Don't clean the output directory,
don't bother parsing any runs for which results seem already to be 
present in the output directory.

=item --decimal I<N>

Number of decimal places to show in scores. Default is 1.

==item --in I<DIR>

Location of session data. Default is F</home/vagrant/working>.

==item --out I<DIR>

Location for results. This will be a directory to be filled with text files,
one corresponding to each Tesserae session in the input directory. Unless
the B<--continue> flag has been set, this contents of this directory will 
be deleted before processing any of the runs. Default is "/vagrant/scores",
which, unlike the "working" directory, is shared by the VM with the host,
so you can see its contents after halting or destroying the virtual machine.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

In theory, you can use --sep I<STRING> to specify the row separator for
output, but F<process_tess_an.R> depends upon this being "\n". If you want
to do something else with the scores, though, you might use e.g. --sep "," so that each run is represented by a single line of comma-separated scores.

=head1 SEE ALSO

=over

=item F<nodelist.pl>

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

The Original Code is extract_scores.pl.

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
use Storable;

# initialize some variables

my $continue = 0;
my $dec = 1;
my $sep = "\n";
my $dir_in = "/home/vagrant/working";
my $dir_out = "/vagrant/scores";
my $help = 0;

# get user options

GetOptions(
   "continue" => \$continue,
   "decimal=i" => \$dec,
   "seperator=s" => \$sep,
   "in" => \$dir_in,
   "out" => \$dir_out,
   "help"  => \$help
);

# print usage if the user needs help
	
if ($help) {

   pod2usage(1);
}

# clean output directory

unless ($continue) {
   print STDERR "Cleaning $dir_out\n";
   remove_tree($dir_out);
   make_path($dir_out);
}

#
# main
#

{
   my @sessions = @{get_session_list($dir_in)};
   
   print STDERR "Reading " . scalar(@sessions) . " Tesserae sessions\n";

   my $t0 = time;

   my $pr = ProgressBar->new(scalar(@sessions));

   for my $session (@sessions) {
      process_scores("$dir_in/$session", "$dir_out/$session.txt");
      $pr->advance;
   }
   
   print sprintf("%.0f seconds\n", (time-$t0)/10^6);
}

#
# subs
#

sub get_session_list {
   my $dir = shift;
   
   print STDERR "Getting session list\n";
   
   opendir(my $dh, $dir) or die "Can't read session directory $dir: $!";
   my @session = grep {/^\d+$/} readdir($dh);
   closedir($dh);
   
   @session = sort @session;
   
   for my $i (1..$#session) {
      my $gap = $session[$i] - $session[$i-1] - 1;
      
      if ($gap) {
         my $unit = $gap > 1 ? "sessions" : "session";
         print STDERR "Missing $gap $unit after $session[$i]\n";
      }
   }
   
   if ($continue) {
      @session = grep {! -e "$dir_out/$_.txt"} @session;
      unless (@session) {
         exit;
      }
   }
   
   return \@session;
}

sub process_scores {
   my ($file_session, $file_results) = @_;
   
   my @scores;
   
   my %match_score = %{retrieve($file_session . "/match.score")};
   
   for my $unit_id_target (keys %match_score) {
      for my $unit_id_source (keys %{$match_score{$unit_id_target}}) {
         push @scores, $match_score{$unit_id_target}{$unit_id_source};
      }
   }
   
   my $fh;
   unless (open ($fh, ">:utf8", $file_results)) {
      warn "Can't write $file_results: $!";
      return;
   }
   
   for (@scores) {
      print $fh sprintf("%.${dec}f\n", $_);
   }
   
   close($fh);
}
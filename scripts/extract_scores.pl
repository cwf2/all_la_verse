use strict;
use warnings;

use File::Path qw/make_path remove_tree/;
use Storable;
use Getopt::Long;

use lib "/vagrant/tesserae/scripts/TessPerl";
use Tesserae;
use EasyProgressBar;

my $continue = 0;
my $dec = 1;
my $sep = "\n";
my $dir_in = "/vagrant/working/sessions";
my $dir_out = "/vagrant/working/scores";

GetOptions(
   "continue" => \$continue,
   "decimal=i" => \$dec,
   "seperator=s" => \$sep,
   "in" => \$dir_in,
   "out" => \$dir_out
);

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
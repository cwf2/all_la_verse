use strict;
use warnings;

use File::Path qw/make_path remove_tree/;
use Parallel::ForkManager;
use XML::LibXML;

use lib "/vagrant/tesserae/TessPerl";
use Tesserae;

my %corpus = %{load_corpus()};
   
my %arg = (
   "--unit" => "phrase",
   "--feature" => "stem",
   "--stop" => "10",
   "--stbasis" => "corpus",
   "--score" => "stem",
   "--dist" => "999",
   "--dibasis" => "freq",
   "--cutoff" => "7"
);

# create/clean output directories

my $output_temp = "/home/vagrant/batch-working";
my $output_html = "/vagrant/claudian/html";
my $output_text = "/vagrant/claudian/tsv";

remove_tree($output_temp);
remove_tree($output_html);
remove_tree($output_text);
make_path($output_temp);
make_path($output_html);
make_path($output_text);

# organize all runs in a list to facilitate parallelization

my @run = @{calc_runs($#files)};
my $ndigit = length(scalar(@run));

#
# main loop
#

my $pm = Parallel::ForkManager->new(2);

for (my $i = 0; $i <= $#run; $i++) {
   # fork
   
   $pm->start and next;
   
   # params for this run
   
   my $source = $files[$run[$i]->[0]]{id};
   my $target = $files[$run[$i]->[1]]{id};
   
   my $name = sprintf("%0${ndigit}d.%s_vs_%s",
         $i,
         $files[$run[$i]->[1]]{nick},
         $files[$run[$i]->[0]]{nick}
   );
   
   # run tesserae search
   
   my $cmd = join(" ",
      "/home/vagrant/tesserae/cgi-bin/read_table.pl",
      "--source" => $source,
      "--target" => $target,
      %arg,
      "--bin" => "$output_temp/$name",
      "--quiet"
   );
   
   print STDERR sprintf("[%d/%d] %s\n", $i+1, scalar(@run), $cmd);
   `$cmd`;
   
   # export tab-separated results
   
   $cmd = join(" ",
      "/home/vagrant/tesserae/cgi-bin/read_bin.pl",
      "--export" => "tab",
      "--sort" => "target",
      "--decimal" => "1",
      "--quiet",
      "$output_temp/$name",
      ">",
      "$output_text/$name.txt"
   );
   
   print STDERR sprintf("[%d/%d] %s\n", $i+1, scalar(@run), $cmd);
   `$cmd`;

   # export html results

   $cmd = join(" ",
      "/home/vagrant/tesserae/cgi-bin/read_bin.pl",
      "--export" => "html",
      "--sort" => "target",
      "--batch" => "10000",
      "--decimal" => "1",
      "--quiet",
      "$output_temp/$name",
      "2>/dev/null",
      ">",
      "$output_html/$name.html"
   );
   
   print STDERR sprintf("[%d/%d] %s\n", $i+1, scalar(@run), $cmd);
   `$cmd`;

   $pm->finish;
}
$pm->wait_all_children;


#
# subroutines
#

sub load_corpus {
   my $file_text = "/vagrant/metadata/authors.xml";
   my $file_auth = "/vagrant/metadata/texts.xml";
}

sub calc_runs {
   my $n = shift;
   
   my @run;
   
   for (my $t = 1; $t <= $n; $t++) {
      for (my $s = 0; $s < $t; $s++) {
         push @run, [$s, $t];
      }
   }
   
   return \@run;
}
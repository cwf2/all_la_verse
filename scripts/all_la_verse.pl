use strict;
use warnings;

use File::Path qw/make_path remove_tree/;
use Parallel::ForkManager;
use XML::LibXML;
use Getopt::Long;

use lib "/home/vagrant/tesserae/scripts/TessPerl";
use Tesserae;

my $continue = 0;
my $tessroot = "/home/vagrant/tesserae";
my $file_runs = "/vagrant/metadata/index_run.txt";
my $file_texts = "/vagrant/metadata/index_text.txt";
my $dir_sessions = "/home/vagrant/working";
my $parallel = 2;
my $shuffle = 1;

my %arg = (
   "--unit" => "line",
   "--feature" => "stem",
   "--stop" => "10",
   "--stbasis" => "both",
   "--score" => "stem",
   "--dist" => "5",
   "--dibasis" => "freq",
   "--cutoff" => "7"
);

GetOptions(
  "continue" => \$continue,
  "texts" => \$file_texts,
  "runs" => \$file_runs,
  "working" => \$dir_sessions,
  "parallel=i" => \$parallel,
  "shuffle!" => \$shuffle
);


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

#!/usr/bin/env perl

=head1 NAME

all_la_verse.pl - batch search of Latin verse corpus

=head1 SYNOPSIS

all_la_verse.pl [options]

=head1 DESCRIPTION

This script does pairwise searches on the entire Latin verse corpus.
The scores for individual runs are extracted using the ancillary script 
F<scripts/extract_scores.pl>. 

These scripts were designed to be run inside a Vagrant virtual machine as part
of the "all_la_verse" experiments at Tesserae. The scores will be used as input
for Neil Bernstein and Kyle Gervais' intertextual density work
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
F<nodelist.pl>. Default is F<output/index_text.txt>.

=item --runs I<FILE>

Name given to the index, created by the present script, of all Tesserae
searches to be performed. Each row of this file has the form

=begin text

  run_id    source_id  target_id

=end text

where I<source_id> and I<target_id> correspond to the I<id> column of
the texts index specified as input above. The default name is 
F<output/index_runs.txt>.

=item --working I<DIR>

Path to working directory, where the completed tess searches store their
session data. NB This directory is entirely cleared before starting, 
unless the B<--continue> flag is set. The default value is 
F<$TESSTMP/la_verse-working>. 

=item --parallel I<N>

The number of Tesserae searches to run in parallel. This argument is passed to
Parallel::ForkManager. The default value is 2. Simultaneously running different
searches on large texts (e.g. Ovid's I<Metamorphoses> or Silius Italicus) can
really eat up RAM. If memory runs out, the currently-running searches tend to
abort and the next ones are run. This can be remedied later using the 
B<--continue> flag (see below). Or use --parallel 0 to turn parallel processing
off.

=item B<--[no]shuffle>

Randomize the order in which the searches are performed. This decreases the
chances of running simultaneous searches on a big text (see above). On by
default; use B<--noshuffle> to have the searches performed in the order
in which they appear in the runs index (see above).

=item B<--[no]quiet>

Pass the B<--quiet> flag to each of the Tesserae searches run. On by default.
You can use B<--noquiet> for debugging if one or more of the searches fail, and
you want to rerun to see what happens (B<--continue> is useful here). This only
really works in conjunction with B<--parallel 0> since otherwise you get output
from multiple searches overlapping.

=item --[no]redo

Automatically rerun any failed searches after the first batch is over. Any run
that didn't produce the expected Tesserae binaries will be deleted and requeued.
This is on by default. Reruns are done at the end, with the --parallel 0 
and B<--noquiet> options set. The assumption is that most failures are the 
result of memory-intensive searches overlapping, so turning off parallel
processing should help. At the same time, turning off B<--quiet> lets you see 
any diagnostic information from Tesserae about why a search is failing.

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
use Storable;

# initialize some variables

my $continue = 0;
my $file_runs = catfile("output", "index_run.txt");
my $file_texts = catfile("output", "index_text.txt");
my $dir_sessions = catfile($fs{tmp}, "la_verse-working");
my $parallel = 2;
my $shuffle = 1;
my $quiet = 1;
my $autoredo = 1;
my $help = 0;

my %tess_arg = (
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
   "texts=s" => \$file_texts,
   "runs=s" => \$file_runs,
   "working=s" => \$dir_sessions,
   "parallel=i" => \$parallel,
   "shuffle!" => \$shuffle,
   "quiet!" => \$quiet,
   "redo!" => \$autoredo,
   "help"  => \$help
);

# print usage if the user needs help
	
if ($help) {

   pod2usage(1);
}

# load corpus

my ($corpus_size, $ref_corpus) = load_corpus($file_texts);

# create/clean output directories

unless ($continue) {
   remove_tree($dir_sessions);
   make_path($dir_sessions);
}

# organize all runs in a list to facilitate parallelization

my $ref_run = $continue ? load_runs($file_runs) : calc_runs($corpus_size);
my $ndigit = ndigit($ref_run);
write_index($file_runs, $ref_run, $ndigit) unless $continue;
$ref_run = shuffle_runs($ref_run) if $shuffle;

# main loop : run searches, capture failed runs
do_searches (
  run => $ref_run,
  corpus => $ref_corpus,
  working => $dir_sessions,
  parallel => $parallel,
  quiet => $quiet,
  tess_arg => \%tess_arg,
  autoredo => $autoredo
);


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
   
   return (scalar(@corpus), \@corpus);
}

sub calc_runs {
   my $n = $_[0] - 1;
   
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
   
   @run = grep {! -d catfile($dir_sessions, $_->{id})} @run;
   
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
      print $fh sprintf("%0${ndigit}i\t%i\t%i\n", 
        $run[$i]->{id}, $run[$i]{source}, $run[$i]{target}
      );
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


sub do_searches {
  # main subroutine: run all the queued searches
  
  my %opt = @_;
  
  my @run = @{$opt{run}};
  my @corpus = @{$opt{corpus}};
  my $quiet = $opt{quiet};
  my $parallel = $opt{parallel};
  my $working = $opt{working};
  my $tessroot = $opt{tessroot};
  my $autoredo = $opt{autoredo};
  my %tess_arg = %{$opt{tess_arg}};
  
  # set up parallel processing
  my $pm;
  if ($parallel) {
     $pm = Parallel::ForkManager->new($parallel);
  }
  
  # loop through queued searches
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
     my $exec = catfile($fs{cgi}, "read_table.pl");
     unless (-e $exec) {
       die "Tesserae script $exec doesn't exist";
     }
     unless (-x $exec) {
       die "Can't execute Tesserae script $exec";
     }
     
     my @args = (
        "--source" => $source,
        "--target" => $target,
        %tess_arg,
        "--bin" => catdir($working, $name)
     );
     if ($quiet) {
       push @args, "--quiet";
     }
     my $cmd = join(" ", $exec, @args);

     print STDERR sprintf("[%d/%d] %s\n", $i+1, scalar(@run), $cmd);
     system $cmd;

     $pm->finish if $parallel;
  }
  $pm->wait_all_children if $parallel;
  
  # check for failed runs
  my @fail = check_incomplete($opt{run}, $opt{corpus}, $working);
  
  if (@fail) {
    # optionally attempt to redo failed runs
    if ($autoredo) {
    
      # delete bad runs from working directory
      print STDERR "Autoredo: cleaning mangled data\n";
    
      for my $run (@fail) {
        my $session = catdir($working, sprintf("%0${ndigit}d", $run->{id}));
        print STDERR "\t" . $session . "\n";
        remove_tree($session);
      }
    
      # re-invoke the main loop
      #  - failed run list as new queue
      #  - turn off parallel processing
      #  - turn off quiet
      #  - turn off auto-redo to avoid infinite loop
    
      do_searches(
        run => \@fail,
        corpus => $ref_corpus,
        working => $dir_sessions,
        parallel => 0,
        quiet => 0,
        tess_arg => \%tess_arg,
        autoredo => 0
      );
    
    } else {
      # if autoredo is off (or has already been tried once)
      #  just warn about missed runs
    
      print STDERR "Consider rerunning with --continue --noquiet --parallel 0\n";
    }
  }
}


sub check_incomplete {
  my ($ref_run, $ref_corpus, $working) = @_;
  my @run = @$ref_run;
  my @corpus = @$ref_corpus;
  
  my @fail;

  print STDERR "Checking integrity of results\n";
  
RUN: for my $run (@run) {
    my $id = $run->{id};
    my $source = $run->{source};
    my $target = $run->{target};
    
    # is there any sign the search happened at all?
    my $session = catdir($working, sprintf("%0${ndigit}d", $id));
    
    unless (-d $session) {
      push @fail, {
        id => $id,
        source => $source,
        target => $target,
        status => "NO DATA"
      };
      next RUN;
    }
  
    # are the Tesserae binaries all there?
    for my $suff (qw/meta source target score/) {
      unless (-e catfile($session, "match.$suff")) {
        push @fail, {
          id => $id,
          source => $source,
          target => $target,
          status => "INCOMPLETE"
        };
        next RUN;
      }
    }

    # check that source, target agree with index      
    my $file_meta = catfile($session, "match.meta");
    my %meta = %{retrieve($file_meta)};
      
    # if metadata don't agree, mark it as bad
    if ($meta{SOURCE} ne $corpus[$source]{label} 
        or $meta{TARGET} ne $corpus[$target]{label}) {
      push @fail, {
        id => $id,
        source => $source,
        target => $target,
        status => "BAD METADATA"
      };
    }
  }

  # put failed runs back in order, just for the heck of it
  @fail = sort {$a->{id} <=> $b->{id}} @fail;
  
  if (@fail) {
    print STDERR sprintf("Warning: %i run%s failed!\n", scalar(@fail),
      scalar(@fail) > 1 ? "s" : "");

    for my $run (@fail) {
      print STDERR join("\t", "", 
        $run->{id}, 
        $corpus[$run->{source}]{label}, 
        $corpus[$run->{target}]{label}, 
        $run->{status}
      ) . "\n";
    }
  }
  
  return @fail;
}

use strict;
use warnings;

use XML::LibXML;
use File::Spec::Functions;
use Storable;

use lib "/home/vagrant/tesserae/scripts/TessPerl";
use Tesserae;
use EasyProgressBar;

my $file_auth = "/vagrant/metadata/authors.xml";
my $file_text = "/vagrant/metadata/texts.xml";
my $file_out = "/vagrant/metadata/index_text.txt";

my $ref_auth_date = load_auth($file_auth);
my $ref_meta = load_text($file_text, $ref_auth_date);
my %meta = %{load_tess($ref_meta)};

my @texts = sort {$meta{$a}->{date} <=> $meta{$b}->{date}} sort keys %meta;

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
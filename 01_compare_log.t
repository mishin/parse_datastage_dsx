use Modern::Perl;
use Test::Builder::Tester tests => 1;
use File::Spec;

use Test::Files;

my $some_file  = File::Spec->catfile(qw/ Parallel_SG_BCE_ACCRED.dsx.log.orig/);
my $other_file = File::Spec->catfile(qw/ Parallel_SG_BCE_ACCRED.dsx.log/);
compare_ok( $some_file, $other_file, "files are the same" );

#    compare_filter_ok( $file1, $file2, \&filter, "they're almost the same");


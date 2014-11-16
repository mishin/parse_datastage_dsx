#! perl
use v5.10;

use FindBin '$RealBin';
use Datahub::Tools qw/read_file enc_terminal/;
use utf8;
use strict;
use warnings;
use Encode::Locale;
use Text::ASCIITable;
use DDP;

enc_terminal();

my ($file_name) = 'orchestrate_code_body.xml';
my $data = read_file($file_name);

my $operator_rx      = qr{\Q#### STAGE: \E(?<stage_name>\w+)};
my $operator_name_rx = qr{\Q## Operator\E\n(?<operator_name>\w+)\n\#};
my $header_rx        = qr{
                  $operator_rx \n
				  $operator_name_rx
                }sx;

my $ORCHESTRATE_BODY_RX = qr{
       (?<stage_body>
		$header_rx
		.*?
		^;
		)
		}sxm;

my $parsed_dsx = start_parse($data);
display_dsx_content($parsed_dsx);

sub display_dsx_content {
    my $parsed_dsx = shift;

    my $t = Text::ASCIITable->new(
        { headingText => 'Parsing ORCHESTRATE of ' . $file_name } );
    $t->setCols( 'Id', 'stage_name', 'operator_name', 'inputs', 'outputs' );
    my $i = 1;
    foreach my $stage ( @{$parsed_dsx} ) {
        my ( $in, $out ) = '';
        if ( ref( $stage->{ins}->{inputs} ) eq "ARRAY" ) {
            $in = join "\n", @{ $stage->{ins}->{inputs} };
        }

        if ( ref( $stage->{ins}->{outputs} ) eq "ARRAY" ) {
            $out = join "\n", @{ $stage->{ins}->{outputs} };
        }
        $t->addRow( $i, $stage->{stage_name}, $stage->{operator_name},
            $in, $out );
        $t->addRowLine();

        $i++;
    }
    print $t;
}

sub start_parse {
    my $data = shift;
    local $/ = '';
    my $i          = 1;
    my @parsed_dsx = ();
    while ( $data =~ m/$ORCHESTRATE_BODY_RX/xsg ) {
        my %stage = ();
        my $ins   = process_stage_body( $+{stage_body} );
        $stage{ins}           = $ins;
        $stage{stage_name}    = $+{stage_name};
        $stage{operator_name} = $+{operator_name};
        push @parsed_dsx, \%stage;
    }
    return \@parsed_dsx;
}

sub process_stage_body {
    my ($stage_body) = @_;
    my %outs;
    my $inputs_rx  = qr{## Inputs\n(?<inputs_name>.*?)(?:#|^;$)}sm;
    my $outputs_rx = qr{## Outputs\n(?<outputs_name>.*?)^;$}sm;

    my ( $inputs, $outputs ) = ( '', '' );
    if ( $stage_body =~ $inputs_rx ) {
        $outs{inputs} = get_inout_links( $+{inputs_name} );
    }
    if ( $stage_body =~ $outputs_rx ) {
        $outs{outputs} = get_inout_links( $+{outputs_name} );
    }
    return \%outs;
}

sub get_inout_links {
    my ($body) = @_;
    my @links = ();

    while (
        $body =~ m/'
					 \w+:
					 (?<link_name>\w+)
					 .v
					 |
					 \[.*?\]
					 (?<link_name>\w+.ds)
					 '/xsg
      )
    {
        push @links, $+{link_name};
    }
    return \@links;

}

__DATA__
  

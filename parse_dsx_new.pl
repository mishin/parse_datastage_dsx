#! perl
use v5.10;

use FindBin '$RealBin';
use Datahub::Tools qw/read_file enc_terminal/;
use utf8;
use strict;
use warnings;
use Encode::Locale;
use Text::ASCIITable;
use Data::Printer {
    output         => 'stdout',
    hash_separator => ':  ',
    return_value   => 'pass',

    #    caller_info    => 1,
};

enc_terminal();

my ($file_name) = 'orchestrate_code_body.xml';
my $data = read_file($file_name);

sub make_regexp {
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
    return $ORCHESTRATE_BODY_RX;
}

my $parsed_dsx = start_parse($data);
display_dsx_content($parsed_dsx);

sub display_dsx_content {
    my $parsed_dsx = shift;

    my $t = Text::ASCIITable->new(
        { headingText => 'Parsing ORCHESTRATE of ' . $file_name } );
    $t->setCols( 'Id', 'stage_name', 'op_name', 'inputs', 'outputs',
        'outs_body' );
    my $i = 1;
    foreach my $stage ( @{$parsed_dsx} ) {
        if (   $stage->{operator_name} eq 'copy'
            && $stage->{stage_name} eq 'DWH_REESTRS_DS' )
        {

            my ( $in, $out ) = ( '', '' );
            if ( $stage->{ins}->{in} eq 'yes' ) {

                #p $stage->{ins}->{inputs};
                for my $inputs ( @{ $stage->{ins}->{inputs} } ) {
                    $in = $in . $inputs->{link_name} . "\n";
                }

                #$in = join "\n", @{ $stage->{ins}->{inputs} };
            }

            if ( $stage->{ins}->{out} eq 'yes' ) {

                #p $stage->{ins}->{outputs};
                #$out = join "\n", @{ $stage->{ins}->{outputs} };
                for my $inputs ( @{ $stage->{ins}->{outputs} } ) {
                    $out = $out . $inputs->{link_name} . "\n";
                }
            }
            $t->addRow( $i, $stage->{stage_name}, $stage->{operator_name},
                $in, $out, $stage->{ins}->{body} );
            $t->addRowLine();

            $i++;
        }
    }
    print $t;
}

sub start_parse {
    my $data                = shift;
    my $ORCHESTRATE_BODY_RX = make_regexp();
    local $/ = '';
    my $i          = 1;
    my @parsed_dsx = ();
    while ( $data =~ m/$ORCHESTRATE_BODY_RX/xsg ) {

=pod
print "\nSTART:\n";
        p $+{stage_name};
        p $+{operator_name};
print "\nbody:\n";
        p $+{stage_body};
=cut

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
    $outs{in}   = 'no';
    $outs{out}  = 'no';
    $outs{body} = $stage_body;

    if ( $stage_body =~ $inputs_rx ) {
        $outs{inputs} = get_inout_links( $+{inputs_name} );
        $outs{in}     = 'yes';
    }
    if ( $stage_body =~ $outputs_rx ) {
        $outs{outputs} = get_inout_links( $+{outputs_name} );
        $outs{out}     = 'yes';
    }
    return \%outs;
}

sub get_inout_links {
    my ($body) = @_;

    #say "\ndebug";
    #p $body;
    my @links = ();
    my $link  = qr{
                   '
                   (?<link_name>
					 \w+:
					 \w+
					 .v)
					 |
					 \[.*?\]			 
					 (?<link_name>
					 \w+.ds
					 )' 
		      }xs;

    #my $link   = qr{
    #     '
    #		 \w+:
    #		 (?<link_name>\w+)
    #		 .v
    #		 |
    #		 \[.*?\]
    #		 (?<link_name>\w+.ds)
    #		 '
    # }xs;
    while ( $body =~ m/$link/g ) {
        my %link_param = ();
        $link_param{link_name} = $+{link_name};
        $link_param{link_type} = $+{link_type};
        push @links, \%link_param;
    }
    return \@links;

}

__DATA__
  

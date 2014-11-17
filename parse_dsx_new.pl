#! perl
use v5.10;

use FindBin '$RealBin';
use utf8;
use strict;
use warnings;
use Encode::Locale;
use Text::ASCIITable;
use Data::Printer {
    output         => 'stdout',
    hash_separator => ':  ',
    return_value   => 'pass',
};


main();

sub main {
    enc_terminal();
    my $file_name  = 'orchestrate_code_body.xml';
    my $data       = read_file($file_name);
    my $parsed_dsx = start_parse($data);
    display_dsx_content($parsed_dsx, $file_name);
}


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

#
# New subroutine "head_of_stage" extracted - Mon Nov 17 10:15:21 2014.
#
sub head_of_stage {
    my ($t, $i, $stage) = @_;

    my ($in, $in_type, $out, $out_type) = ('', '', '', '');
    if ($stage->{ins}->{in} eq 'yes') {
        $in      = join "\n", $_->{link_name} for @{$stage->{ins}->{inputs}};
        $in_type = join "\n", $_->{link_type} for @{$stage->{ins}->{inputs}};

    }

    if ($stage->{ins}->{out} eq 'yes') {
        $out = join "\n", $_->{link_name} for @{$stage->{ins}->{outputs}};
        $out_type = join "\n", $_->{link_type}
          for @{$stage->{ins}->{outputs}};

    }
    $t->addRow($i, $stage->{stage_name}, $stage->{operator_name},
        $in, '', '', '', '', $out, '', '', '', '');
    return $t;
}

#
# New subroutine "show_in_fields" extracted - Mon Nov 17 10:20:07 2014.
#
sub show_in_fields {
    my $t     = shift;
    my $stage = shift;

    if ($stage->{ins}->{in} eq 'yes'
        && ${$stage->{ins}->{inputs}}[0]->{is_param} eq 'yes')
    {
        $t->addRowLine();
        my $j = 1;
        for my $f (@{${$stage->{ins}->{inputs}}[0]->{params}}) {
            $t->addRow('', '', '', '', $j, $f->{field_name}, $f->{field_type},
                $f->{is_null}, '', '', '', '', '');
            $t->addRowLine();
            $j++;
        }
    }

    return $t;
}


#
# New subroutine "show_out_fields" extracted - Mon Nov 17 10:20:53 2014.
#
sub show_out_fields {
    my $t     = shift;
    my $stage = shift;

    if ($stage->{ins}->{out} eq 'yes'
        && ${$stage->{ins}->{outputs}}[0]->{is_param} eq 'yes')
    {
        $t->addRowLine();
        my $y = 1;
        for my $f (@{${$stage->{ins}->{outputs}}[0]->{params}}) {
            $t->addRow('', '', '', '', '', '', '', '', '', $y,
                $f->{field_name}, $f->{field_type}, $f->{is_null});
            $t->addRowLine();
            $y++;
        }
    }
    return $t;
}


#
# New subroutine "display_main_header" extracted - Mon Nov 17 10:30:17 2014.
#
sub display_main_header {
    my $file_name = shift;

    my $t = Text::ASCIITable->new(
        {headingText => 'Parsing ORCHESTRATE of ' . $file_name});
    $t->setCols(
        'Id',      'stage_name', 'op_name',    'inputs',
        'num',     'field_name', 'field_type', 'is_null',
        'outputs', 'num',        'field_name', 'field_type',
        'is_null'
    );
    return $t;
}

sub display_dsx_content {
    my ($parsed_dsx, $file_name) = @_;

    my $t = display_main_header($file_name);

    my $i = 1;
    foreach my $stage (@{$parsed_dsx}) {
        if ($stage->{stage_name} eq 'T199') {
            $t = head_of_stage($t, $i, $stage);
            $t = show_in_fields($t, $stage);
            $t = show_out_fields($t, $stage);

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
    my @parsed_dsx = ();
    while ($data =~ m/$ORCHESTRATE_BODY_RX/xsg) {
        my %stage = ();
        my $ins   = process_stage_body($+{stage_body});
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

=pod
## Inputs
0< [] 'LJ108:L109.v'
## Outputs
0> [] 'T199:INS.v'
1> [] 'T199:UPD.v'
;
=cut    

    my $inputs_rx  = qr{## Inputs\n(?<inputs_name>.*?)(?:#|^;$)}sm;
    my $outputs_rx = qr{## Outputs\n(?<outputs_name>.*?)^;$}sm;

    my ($inputs, $outputs) = ('', '');
    $outs{in}   = 'no';
    $outs{out}  = 'no';
    $outs{body} = $stage_body;

    if ($stage_body =~ $inputs_rx) {
        $outs{inputs} = get_inout_links($+{inputs_name});
        $outs{in}     = 'yes';
    }
    if ($stage_body =~ $outputs_rx) {
        $outs{outputs} = get_inout_links($+{outputs_name});
        $outs{out}     = 'yes';
    }
    return \%outs;
}

sub get_inout_links {
    my ($body) = @_;
    my @links  = ();
    my $link   = qr{\d+
    (?:<|>)
    (?:\||)
    \s
         \[
         (?<link_type>.*?)
         \]
                   \s 
         '
         (?:
         (?<link_name>
					 \w+:
					 \w+
					 .v
		 )
					 |
					 \[.*?\]			 
		(?<link_name>
					 \w+.ds
		)
		)' 
		      }xs;

    while ($body =~ m/$link/g) {
        my %link_param = ();
        $link_param{link_name} = $+{link_name};
        $link_param{link_type} = $+{link_type};
        $link_param{is_param}  = 'no';
        if (length($link_param{link_type}) >= 6
            && substr($link_param{link_type}, 0, 6) eq 'modify')
        {
            $link_param{is_param} = 'yes';
            $link_param{params}   = get_fields($+{link_type});
        }
        push @links, \%link_param;
    }
    return \@links;

}

sub get_fields {
    my $body_for_fields = shift;

    #p $body_for_fields;
    my @fields = ();
    my $field  = qr{
    (?<field_name>\w+)
    :
    (?<is_null>not_nullable|nullable)\s
    (?<field_type>.*?)
    =
    \g{field_name}
    ;
     }xs;

    while ($body_for_fields =~ m/$field/g) {
        my %field_param = ();
        $field_param{field_name} = $+{field_name};
        $field_param{is_null}    = $+{is_null};
        $field_param{field_type} = $+{field_type};
        push @fields, \%field_param;
    }
    return \@fields;

}

sub enc_terminal {

    if (-t) {
        binmode(STDIN,  ":encoding(console_in)");
        binmode(STDOUT, ":encoding(console_out)");
        binmode(STDERR, ":encoding(console_out)");
    }
}

sub read_file {
    my ($filename) = @_;

    open my $in, '<:encoding(UTF-8)', $filename
      or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;

    return $all;
}
__DATA__
  

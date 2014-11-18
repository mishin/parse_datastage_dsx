use 5.14.0;
use Dsx_parse::Tools qw/get_job_name
  enc_terminal
  read_file
  parse_orchestrate_body
  reformat_links
  show_dsx_content
  invoke_orchestrate_code/;

main(shift);

sub main {
    my $file_name = shift or die "Usage: $0 file_4_transform\n";
    enc_terminal();
    get_job_name($file_name);

    #my $data       = invoke_orchestrate_code($file_name);
    #my $parsed_dsx = parse_orchestrate_body($data);
    #my $only_links = reformat_links($parsed_dsx);
    #show_dsx_content( $parsed_dsx, $file_name );
}


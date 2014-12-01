#perltidy -b Dsx_parse/Tools.pm
perl simple_parse.pl $1 > $1.log 2>&1
perl 01_compare_log.t

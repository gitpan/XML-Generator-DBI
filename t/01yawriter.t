use Test;
BEGIN {
    eval {
        require XML::Handler::YAWriter;
    };
    if ($@) {
        print "1..0 # Skipping test on this platform\n";
        $skip = 1;
    }
    else {
        plan tests => 5;
    }
}
use XML::Generator::DBI;
use DBI;
unless ($skip) {

ok(1);

my $handler = XML::Handler::YAWriter->new(AsString => 1,
	Pretty => {
		CatchEmptyElement => 1,
		# PrettyWhiteIndent => 1,
		# PrettyWhiteNewline => 1,
	},
	);

ok($handler);

my ($user, $pwd, $driver, $extra, $query) = read_config();

my $dbh = DBI->connect("dbi:${driver}:${extra}", $user, $pwd);

my $generator = XML::Generator::DBI->new(
        Handler => $handler,
        dbh => $dbh,
        );
ok($generator);

my $str = $generator->execute($query);
ok($str);

warn($str);

my $attrs = $generator->execute($query, undef, AsAttributes => 1, ShowColumns => 1);
ok($attrs);

warn($attrs)

}

sub read_config {
    open(FH, "PWD") || die "Can't open PWD: $!";
    local $/;
    my $config = <FH>;
    my @ret = (
            get_config($config, 'UID'),
            get_config($config, 'PWD'),
            get_config($config, 'DRIVER'),
            get_config($config, 'EXTRA'),
            get_config($config, 'QUERY'),
            );
    return @ret;
}

sub get_config {
    my ($config, $param) = @_;
    if ($config =~ /^$param\s*?=\s*?(.*?)$/m) {
        return $1;
    }
    return '';
}

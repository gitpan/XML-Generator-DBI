use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'XML::Generator::DBI',
    'VERSION_FROM' => 'DBI.pm', # finds $VERSION
    'PREREQ_PM' => { MIME::Base64 => 2.00 },
);

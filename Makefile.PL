# $Id: Makefile.PL,v 1.4 2002/02/07 17:35:14 matt Exp $

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'XML::Generator::DBI',
    'VERSION_FROM' => 'DBI.pm', # finds $VERSION
    'PREREQ_PM' => {
        'MIME::Base64' => 2.00,
        'XML::SAX::Base' => 1.00,
    },
    'ABSTRACT_FROM' => 'DBI.pm',
    'AUTHOR' => 'Matt Sergeant <matt@sergeant.org>',
);

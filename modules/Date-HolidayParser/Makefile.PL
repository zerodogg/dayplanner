use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Date::HolidayParser',
    AUTHOR              => 'Eskild Hustvedt <zerodogg@cpan.org>',
    VERSION_FROM        => 'lib/Date/HolidayParser.pm',
    ABSTRACT_FROM       => 'lib/Date/HolidayParser.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Date-HolidayParser-*' },
);

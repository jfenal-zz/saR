use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'saR',
    license             => 'perl',
    dist_author         => q{Jérôme Fenal <jfenal@redhat.com>},
    dist_version_from   => 'lib/saR.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'saR-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

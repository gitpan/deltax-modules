use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'DeltaX',
		'VERSION_FROM' => 'DeltaX/Database.pm',
    'PREREQ_PM'		=> {
			DBI => 0,
			Time::HiRes => 0
    }, # e.g., Module::Name => 1.1
);

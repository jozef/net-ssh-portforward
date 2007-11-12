use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Net::SSH::PortForward',
    VERSION_FROM => 'lib/Net/SSH/PortForward.pm', # finds $VERSION
	PREREQ_PM    => {
		Carp::Clan    => 0,
	},
	($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Net/SSH/PortForward.pm', # retrieve abstract from module
		AUTHOR         => 'Jozef Kutej <jozef@kutej.net>') : ()),
	(MM->can('signature_target') ? (SIGN => 1) : ()),
);

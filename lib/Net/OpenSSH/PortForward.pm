package Net::OpenSSH::PortForward;

=head1 NAME

Net::OpenSSH::PortForward - do port forwarding using openssh

=head SYNOPSIS

	use Net::OpenSSH::PortForward;
	
	$port_forward = Net::OpenSSH::PortForward->new(
		'ssh_host'  => 'common_host',
		'username'  => 'common_username',
	);
	
	$port_forward->local(
		'local_port' => 8080,
		'host'       => 'some_other_host',
		'host_port'  => 80,
	);

=head1 DESCRIPTION

Used to do (local for the moment) port forwarding using OpenSSH ssh command.

Will fork and exec 'ssh -L ...'. Remembering the pids for later clean up.

=cut

use warnings;
use strict;

use base 'Class::Accessor::Fast';

use Carp::Clan;

=head1 PROPERTIES

	ssh_host
	ssh_port
	host
	host_port
	username

All of these will be used as default for later calls.

=over 4

=item ssh_host

Hostname where the ssh connection will be made.

=item ssh_port

Port used by "ssh_host". Default 22.

=item host

Hostname to which "ssh_host" will make connection

=item host_port

Port on "host" to make connection to.

=item username

Username to use.

=item bind_address

Bind address for local forwarded connections.

=back

=cut

__PACKAGE__->mk_accessors(qw{
	ssh_host
	ssh_port
	host_port
	username
	bind_address
});

my @pids;

=head1 METHODS

=head2 new()

Construct object and setup defaults. You can pass any property
that will be used as default for later calls. If you need no
default then call just ->new();

=cut

sub new {
	my $self = shift->SUPER::new({ @_ });
	
	# defaults
	$self->ssh_port(22) if not defined $self->ssh_port;
	$self->bind_address('127.0.0.1') if not defined $self->bind_address;
	
	return $self;
}

=head2 local()

Make ssh -L redirection.

	->local(
		'ssh_host'     => 'ssh.server',
		'ssh_port'     => 22,
		'bind_address' => '127.0.0.1',
		'host'         => 'unreachable.http.server'
		'host_port'    => 80,
		'local_port'   => 8080,
		'username'     => 'someusername',
	);

See PROPERTIES for description.

=cut

sub local {
	my $self = shift;
	my %args = @_;

	# args & defaults	
	my $ssh_host     = $args{'ssh_host'} || $self->ssh_host;
	my $ssh_port     = $args{'ssh_port'} || $self->ssh_port;
	my $bind_address = $args{'bind_address'} || $self->bind_address;
	my $host         = $args{'host'} || $self->host;
	my $host_port    = $args{'host_port'} || $self->host_port;
	my $local_port   = $args{'local_port'} || $host_port;
	my $username     = $args{'username'} || $self->username;
	
	# check args
	croak 'pass ssh_host'  if not defined $ssh_host;
	croak 'pass host'      if not defined $host;
	croak 'pass host port' if not defined $host_port;
	croak 'pass username'  if not defined $username;

	my $cmd =
		'ssh -L '
		.$bind_address
		.':'.$local_port
		.':'.$host
		.':'.$host_port
		.' -l '.$username
		.' '.$ssh_host
		.' -p '.$ssh_port
		.' -N'
		.' 2>&1'
	;
	print STDERR '+ '.$cmd."\n" if $ENV{'IN_DEBUG_MODE'};

	my $pid = open(my $ssh_pipe, "-|");
	die 'fork failed' if not defined $pid;
	
	# child will do exec of ssh
	if ($pid == 0) {
		# redirect stderr to stdout 
		open STDERR, '>&', \*STDOUT;
		
		exec $cmd;
		# never retturning back...
	}

	# add pid to the list for later cleanup
	push @pids, $pid;
	
	if (defined wantarray) {
		return $ssh_pipe, $pid;
	}
	else {
		return $ssh_pipe;
	}
}

=head2 DESTROY

Will forked ssh processes cleanup by sending kill 15 to each of them.

=cut

sub DESTROY {
	my $self = shift;
	
	$self->NEXT::DESTROY(@_);
	
	foreach my $pid (@pids) {
		# sigterm the ssh process
		kill 15, $pid;
	}
	
	return;
}

=head1 INTERNAL

=head2 $SIG{CHLD}

Captures SIGCHLD to make note of died ssh. Will call previous SIGCHLD
handler if defined.

=cut

my $previous_sigchld = $SIG{CHLD};
$SIG{CHLD} = sub {
	my $pid = wait;
	
	# filter out died pif from the list so we will not send kill to it
	@pids = grep { $_ ne $pid } @pids;
	
	$previous_sigchld->() if defined $previous_sigchld;
};

1;


=head1 AUTHOR

Jozef Kutej, E<lt>jozef@kutej.netE<gt>

=cut

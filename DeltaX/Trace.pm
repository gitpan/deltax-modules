#-----------------------------------------------------------------
package DeltaX::Trace;
#-----------------------------------------------------------------
# $Id: Trace.pm,v 1.1.1.1 2003/02/25 12:53:28 spicak Exp $
#
# (c) DELTA E.S., 2002 - 2003
# This package is free software; you can use it under "Artistic License" from
# Perl.
#-----------------------------------------------------------------

$DeltaX::Trace::VERSION = '1.0';

use Exporter;
use Carp;

use vars qw(@ISA @EXPORT @EXPORT_OK %options);
@ISA = qw(Exporter);
@EXPORT = qw(trace_set trace);
@EXPORT_OK = qw(error warn info debug _tspecial);

%$options = (		
	trace_file			 => '/var/tmp/trace.log',
	trace_error_file => 1,
	trace_error_std  => 0,
	trace_warn_file  => 1,
	trace_warn_std	 => 0,
	trace_info_file  => 1,
	trace_info_std	 => 0,
	trace_debug_file => 1,
	trace_debug_std  => 0,
	_special				 => '',
	trace_pid				 => 0
); 

sub trace_set {

	croak ("trace_set() called with odd number of parameters - should be of the form field => value")
		if (@_ % 2);

	for (my $x = 0; $x <= $#_; $x += 2) {
		croak ("Unkown parameter $_[$x] in trace_set()")
			unless exists $options->{lc($_[$x])};
		$options->{lc($_[$x])} = $_[$x+1];
	}

}

sub trace {

	my $mtype = uc(shift);

	my $pos = 0;
	my (undef, $mfile, $mline) = caller($pos);
	my (undef, undef, undef, $msub) = caller($pos+1);
	my ($l_mfile, $l_mline, $l_msub) = ($mfile, $mline, $msub);
	$msub = 'main' if ! $msub;
	while ($l_msub =~ /^DeltaX::Trace/) {
		$pos++;
		($l_mfile, $l_mline, $l_msub) = ($mfile, $mline, $msub);
		(undef, $mfile, $mline) = caller($pos);
		(undef, undef, undef, $msub) = caller($pos+1);
		$msub = 'main' if ! $msub;
	}
	if ($l_msub eq 'main') {
		($mfile,$mline,$msub) = ($l_mfile,$l_mline,$l_msub);
		$l_msub = '';
	}

	if ($options->{_special}) {
		$mfile = $options->{_special};
		$msub = '';
	}
	if ($options->{trace_pid}) {
		$mfile .= " ($$)";
	}

	my $to_file = 0;
	my $to_std	= 0;
	my $title		= '';
	for ($mtype) {
		/^E/ && do {
								$to_file = $options->{trace_error_file};
								$to_std  = $options->{trace_error_std};
								$title	 = 'ERROR';
								last;
							 };
		/^W/ && do {
								$to_file = $options->{trace_warn_file};
								$to_std  = $options->{trace_warn_std};
								$title	 = 'WARN';
								last;
							 };
		/^I/ && do {
								$to_file = $options->{trace_info_file};
								$to_std  = $options->{trace_info_std};
								$title	 = 'INFO';
								last;
							 };
		/^D/ && do {
								$to_file = $options->{trace_debug_file};
								$to_std  = $options->{trace_debug_std};
								$title	 = 'DEBUG';
								last;
							 };
	}
	
	my $msg = '';
	while (@_) { $msg = $msg . ' ' . shift; }
	my $called = '';
	if ($l_msub and ($msub ne $l_msub)) {
		$called = " (... called from $l_msub)";
	}
	$msg = "$title at $msub ($mfile) [$mline]: $msg $called";

	# get the stack for error
	#my @stack = get_stack() if $mtype eq 'E';

	# stderr output
	if ($to_std)	{ print STDERR "$msg\n"; }
	if ($to_file) { 
		if (open OUT, ">>".$options->{trace_file} ) {
			print OUT scalar localtime, " $msg\n";
			#if ($mtype eq 'E') { # print the stack
			#	print OUT "  *".join("\n	*", @stack)."\n";
			#}
			close OUT;
		}
	}
}

sub error { trace('E', @_); }
sub warn	{ trace('W', @_); }
sub info	{ trace('I', @_); }
sub debug { trace('D', @_); }

sub _tspecial {
		$options->{_special} = shift;
}

# get the stack - based on Carp::Heavy
sub get_stack {
	my @stack;

	my ($pack, $file, $line, $sub, $hargs, $eval, $require);
	my (@a);
	my $i = 2;
	# let's go
	while (do { { package DB; @a = caller($i++) } } ) {
		# local copies
		($pack, $file, $line, $sub, $hargs, undef, $eval, $require) = @a;
		# subroutine name
		if (defined $eval) {
			if ($require) {
				$sub = "require $eval";
			}
			else {
				$eval =~ s/([\\\'])/\\$1/g;
				if ($MAX_EVAL and length($eval) > $MAX_EVAL) {
					substr($eval, $MAX_EVAL) = '...';
				}
				$sub = "eval '$eval'";
			}
		}
		elsif ($sub eq '(eval)') {
			$sub = "eval {...}";
		}
		# arguments
		if ($hargs) {
			# local copy
			@a = @DB::args;
			# check the number of arguments
			if ($MAX_ARGS and @a > $MAX_ARGS) {
				$#a = $MAX_ARGS;
				$a[$#a] = '...';
			}
			# get them all
			for (@a) {
				$_ = 'undef', next unless defined $_;
				if (ref $_) {
					# force string representation...
					$_ .= '';
				}
				s/'/\\'/g;
				# check the length
				if ($MAX_ARG_LEN and length > $MAX_ARG_LEN) {
					substr($_, $MAX_ARG_LEN) = '...';
				}
				# quote (not for numbers)
				$_ = "'$_'" unless /^-?[\d.]+$/;
			}
			$sub .= '(' . join(', ', @a) . ')';
		}

		push @stack, "$sub at $file:$line";
	}
	return @stack;
}

1;

=head1 NAME

DeltaX::Trace - Perl module for writing log messages

     _____
    /     \ _____    ______ ______ ___________
   /  \ /  \\__  \  /  ___//  ___// __ \_  __ \
  /    Y    \/ __ \_\___ \ \___ \\  ___/|  | \/
  \____|__  (____  /____  >____  >\___  >__|
          \/     \/     \/     \/     \/        project


=head1 SYNOPSIS

 use DeltaX::Trace;    # exports only trace() and trace_set()
 use DeltaX::Trace qw/error warn info debug/;

 trace_set(trace_file=>'my_log_file.log');

 trace('D', "This is", "message");
 warn("This is warning");

=head1 FUNCTIONS

=head2 trace_set()

Used to set tracing options (parameters are in key => value form):

=over

=item trace_file

File to write trace messages (default is /var/tmp/trace.log).

=item trace_error_file

If set, error messages will be written to file (default is true).

=item trace_error_std

If set, error messages will be written to stderr (default is false).

=item trace_warn_file

If set, warning messages will be written to file (default is true).

=item trace_warn_std

If set, warning messages will be written to stderr (default is false).

=item trace_info_file

If set, info messages will be written to file (default is true).

=item trace_info_std

If set, info messages will be written to stderr (default is false).

=item trace_debug_file

If set, debug messages will be written to file (default is true).

=item trace_debug_std

If set, debug messages will be written to stderr (default is false).

=item trace_pid

Is set, process ID will be attached to every message.

=back

=head2 trace()

This function actually creates and writes a message. First argument is a type of
a message (E, W, I, D), other parameters are joined together into one line (with
spaces).

=head2 error()

Works as trace('E', ...).

=head2 warn()

Works as trace('W', ...).

=head2 info()

Works as trace('I', ...).

=head2 debug()

Works as trace('D', ...).

=head2 _tspecial()

Function for masser.fcgi - this value is printed instead of file name (if set).

=head2 get_stack()

Returns stack (as an array) - based on Carp::Heavy code.

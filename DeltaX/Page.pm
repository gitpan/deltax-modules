#-----------------------------------------------------------------
package DeltaX::Page;
#-----------------------------------------------------------------
# $Id: Page.pm,v 1.1.1.1 2003/02/25 12:53:28 spicak Exp $
#
# (c) DELTA E.S., 2002 - 2003
# This package is free software; you can use it under "Artistic License" from
# Perl.
#
# This package uses some ideas from Perl Embeding Engine
# (from William Tan, you can see it at pee.sourceforge.net)
#-----------------------------------------------------------------

$DeltaX::Page::VERSION = '1.0';

use strict;
use Carp;

#-----------------------------------------------------------------
sub new {
#-----------------------------------------------------------------
# CONSTRUCTOR
#
	my $pkg = shift;
	my $self = {};
	bless ($self, $pkg);

	my $filename = shift;
	croak ("You must supply filename!") unless defined $filename;
	$self->{filename} = $filename;
	$self->{error}		= '';

	croak ("$pkg created with odd number of parameters - should be of the form option => value")
		if (@_ % 2);
	for (my $x = 0; $x <= $#_; $x += 2) {
		$self->{special}{$_[$x]} = $_[$x+1];
	}

	return $self;
}
# END OF new()

#-----------------------------------------------------------------s
sub compile {
#-----------------------------------------------------------------
#
	my $self = shift;
	my $do_prints = shift;
	if (!defined $do_prints) { $do_prints = 1; }

	# read file
	if (! open (INF, $self->{filename})) {
		$self->{error} = "Cannot open file: $!";
		return 0;
	}

	$self->{buffer} = '';
	while (<INF>) { $self->{buffer} .= $_; }
	close INF;

	$self->{cursor} = 0;
	$self->{blength} = length($self->{buffer});

	my $token;
	my $type = 0;
	$self->{translated} = '';

	while ( ($type = $self->_next_token(\$token)) != -1 ) {
		if ($type == 0) {					# NORMAL BLOCK => print
			if ($token =~ /^[\s\n]*$/gs) { next; }
			$token = _escape($token);
			$self->{translated} .= "print \"$token\";\n" if $do_prints;
		} else {							# CODE
			$token =~ s/<\?(.*)\?>/$1/gs;
			
			if ($token =~ /^-.*$/s) {		# comment
				next;
			} elsif ($token =~ /^=(.*)$/s) {
				$self->{translated} .= "print ($1);\n";
			} elsif ($token =~ /^!(.*)$/sm) {
				# special command
				my $tmp = $self->_special($1);
				if (!defined $tmp) { return 0; }
				$self->{translated} .= $tmp;
			} else {
				# normal code
				$self->{translated} .= $token;
			}
		}

	}

	$self->{buffer} = '';
	return 1;
}
# END OF compile()

#-----------------------------------------------------------------
sub get_error {
#-----------------------------------------------------------------
#
	my $self = shift;

	return $self->{error};
}
# END OF get_error()

#-----------------------------------------------------------------
sub _next_token {
#-----------------------------------------------------------------
#
	my $self = shift;
	my $token = shift;
	
	if ($self->{cursor} == ($self->{blength} - 1)) {
		$$token = '';
		return -1;		# no more data
	}

	my $pos = index($self->{buffer}, '<?', $self->{cursor});
	if ($pos == -1) {
		$$token = substr($self->{buffer}, $self->{cursor});
		$self->{cursor} = $self->{blength} - 1;
		return 0;			# normal text
	} elsif ($pos > $self->{cursor}) {
		$$token = substr($self->{buffer}, $self->{cursor}, $pos - $self->{cursor});
		$self->{cursor} = $pos;
		return 0;			# till here normal text
	} else {
		my $end = index ($self->{buffer}, '?>', $pos);
		if ($end == -1) {
			$$token = substr($self->{buffer}, $self->{cursor});
			$self->{cursor} = $self->{blength} - 1;
			return 1;		# code
		}
		$$token = substr($self->{buffer}, $pos, ($end - $pos + 2));
		$self->{cursor} = $end + 2;
		return 1;
	}

}
# END OF _next_token()

#-----------------------------------------------------------------
sub _special {
#-----------------------------------------------------------------
#
	my $self = shift;
	my $token = shift;

	$token =~ s/^\s*//g;
	
	if ($token =~ /^include/) {
		$token =~ /^include\s+(\S+)\s*$/;
		return $self->_include($1, 'include');
	}
	if ($token =~ /^package/) {
		$token =~ /^package\s+(\S+)\s*$/;
		return $self->_include($1, 'package');
	}

	$token =~ /^(\S+)\s*(.*)$/s;
	my @args;
	if ($2) { @args = split(/,/, $2); }
	# other special command
	if (! exists $self->{special}{$1}) {
		if ($#args > -1) { return "$1($2);\n"; }
								else { return "$1();\n"; }
	}
	return $self->{special}{$1}->(@args);

}
# END OF _special

#-----------------------------------------------------------------
sub _include {
#-----------------------------------------------------------------
#
	my $self = shift;
	my $arg  = shift;
	my $type = shift;

	# relative path!
	if ($arg !~ /^\//) {
		if ($self->{filename} =~ /^(.*)\/[^\/]*$/) {
			if ($self->{special}{$type}) {
				$arg = $self->{special}{$type}->($arg);
			} else {
				$arg = "$1/$arg";
			}
		}
	}
	if (!$arg) { 
		$self->{error} = "$type: no file found";
		return undef;
	}

	my @spec;
	foreach my $s (sort keys %{$self->{special}}) {
		push @spec, $s, $self->{special}{$s};
	} 
	my $inc = new DeltaX::Page($arg, @spec);
	if ($inc->compile()) {
		return "\n#START $type $arg\n".$inc->{translated}."#END $type $arg\n\n\n";
	} else {
		$self->{error} = "include: unable to compile '$arg': ". $inc->get_error();
		return undef;
	}
}
# END OF _include()

#-----------------------------------------------------------------
sub _escape { 
#-----------------------------------------------------------------
#
	my $text = shift;

	$text =~ s/\\/\\\\/g;
	$text =~ s/\n/\\n/g;
	$text =~ s/\t/\\t/g;
	$text =~ s/'/\\'/g;
	$text =~ s/"/\\"/g;
	$text =~ s/\$/\\\$/g;
	$text =~ s/\%/\\\%/g;
	$text =~ s/\@/\\\@/g;
	$text =~ s/&/\\&/g;
	$text =~ s/`/\\`/g;
	$text =~ s/\|/\\\|/g;

	return $text;
}
# END OF escape()

#-----------------------------------------------------------------
sub DESTROY {
#-----------------------------------------------------------------
#
	my $self = shift;

}
# END OF DESTROY()

1;

=head1 NAME

DeltaX::Page - Perl module for parsing pages for masser

     _____
    /     \ _____    ______ ______ ___________
   /  \ /  \\__  \  /  ___//  ___// __ \_  __ \
  /    Y    \/ __ \_\___ \ \___ \\  ___/|  | \/
  \____|__  (____  /____  >____  >\___  >__|
          \/     \/     \/     \/     \/        project


=head1 SYNOPSIS

 use DeltaX::Page;

 my $page = new DeltaX::Page('myfile.pg');
 if (!$page->compile()) {
  # write some error
 }
 else {
  my $code = $page->{translated};
 }

=head1 FUNCTIONS

=head2 new()

Constructor. It has one required parameter - name of file to parse. Other
parameters are in "directive => sub reference" form (see L<"DIRECTIVES">).

=head2 compile()

Tries to compile given file to perl code (which can be evaled). See L<"FILE
SYNTAX"> for more information. Returns true in case of success, otherwise
returns false.

=head2 get_error()

Returns textual representation of error (only valid after compile() call).

=head1 FILE SYNTAX

This module is parsing page code for masser (see masser.sourceforge.net) - it's
something like perl code embeded in HTML (or XML or other) code. It compiles
everything to print statements, except this:

=over

=item *

everything between <?!- and -!?> is a comment and is ignored

=item *

everything between <? and ?> is a perl code and is included unchanged

=item *

<?=token?> is translated to print token; (remember this semicolon!)

=item *

<?!directive [arguments]?> is processed externally (see L<"DIRECTIVES">)

=back

Example:

 Source code:
  <?- this is a test -?>
  <h1>Hi, welcome to <?=$app_name?>!</h1>
  
  It's 
  <?
    my (undef, undef, undef, $day, $mon, $yer) = localtime();
    $mon++; $yer+=1900;
    print sprintf("%02d.%02d.%04d", $day, $mon, $yer);
  ?>
  <br/>
  See you later...
  
 Compiled code:
  print "<h1>Hi, welcome to ";
  print $app_name;
  print "!</h1>";
  print "\n\n";
  print "It's\n";
    my (undef, undef, undef, $day, $mon, $yer) = localtime();
    $mon++; $yer+=1900;
    print sprintf("%02d.%02d.%04d", $day, $mon, $yer);
  print "\n<br/>\nSee you later\n";

  [code was made a little bit readable :-)]

=head1 DIRECTIVES

Everything in <?!directive [arguments]?> is a special directive. Module knows
these directives:

=over

=item include

<?!include file?> - includes given file, this means tries to read and compile
this file and (in case of success) includes resulting code into actual code.

=item package

<?!package file?> - works as include

=item everything other

Every other directive must be defined in new() function and apropriate function
will be called (arguments will be given to this function - if there are any).
Everything which is returned by this function is included in the code (function
must return true value - at least one space, if it returns false, it is detected
as an error).
You can define directive in new() for include and package too, but this doesn't
change include or package itself, but module expects that called function
returns real full path to file to be included.

Example:

 sub my_include {
  my $filename = shift;
  # only relative path
  return substr($filename, rindex($filename,'/')+1);
 }

 sub my_javascript {
  my $javascript_name = shift;
  # code to give someone know that JavaScript code must be generated...
  return "$cgi->add_javascript('$javascript_name');";
 }
 
 my $page = new DeltaX::Page('test.pg',include=>\&my_include,
  javascript=>\&my_javascript);

=back

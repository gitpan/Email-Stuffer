use strict;
use warnings;
package Email::Stuffer;
# ABSTRACT: A more casual approach to creating and sending Email:: emails
$Email::Stuffer::VERSION = '0.010'; # TRIAL
#pod =head1 SYNOPSIS
#pod
#pod   # Prepare the message
#pod   my $body = <<'AMBUSH_READY';
#pod   Dear Santa
#pod   
#pod   I have killed Bun Bun.
#pod   
#pod   Yes, I know what you are thinking... but it was actually a total accident.
#pod   
#pod   I was in a crowded line at a BayWatch signing, and I tripped, and stood on
#pod   his head.
#pod   
#pod   I know. Oops! :/
#pod   
#pod   So anyways, I am willing to sell you the body for $1 million dollars.
#pod   
#pod   Be near the pinhole to the Dimension of Pain at midnight.
#pod   
#pod   Alias
#pod
#pod   AMBUSH_READY
#pod   
#pod   # Create and send the email in one shot
#pod   Email::Stuffer->from     ('cpan@ali.as'             )
#pod                 ->to       ('santa@northpole.org'     )
#pod                 ->bcc      ('bunbun@sluggy.com'       )
#pod                 ->text_body($body                     )
#pod                 ->attach_file('dead_bunbun_faked.gif' )
#pod                 ->send;
#pod
#pod =head1 DESCRIPTION
#pod
#pod B<The basics should all work, but this module is still subject to
#pod name and/or API changes>
#pod
#pod Email::Stuffer, as its name suggests, is a fairly casual module used
#pod to stuff things into an email and send them. It is a high-level module
#pod designed for ease of use when doing a very specific common task, but
#pod implemented on top of the light and tolerable Email:: modules.
#pod
#pod Email::Stuffer is typically used to build emails and send them in a single
#pod statement, as seen in the synopsis. And it is certain only for use when
#pod creating and sending emails. As such, it contains no email parsing
#pod capability, and little to no modification support.
#pod
#pod To re-iterate, this is very much a module for those "slap it together and
#pod fire it off" situations, but that still has enough grunt behind the scenes
#pod to do things properly.
#pod
#pod =head2 Default Transport
#pod
#pod Although it cannot be relied upon to work, the default behaviour is to
#pod use C<sendmail> to send mail, if you don't provide the mail send channel
#pod with either the C<transport> method, or as an argument to C<send>.
#pod
#pod (Actually, the choice of default is delegated to
#pod L<Email::Sender::Simple>, which makes its own choices.  But usually, it
#pod uses C<sendmail>.)
#pod
#pod =head2 Why use this?
#pod
#pod Why not just use L<Email::Simple> or L<Email::MIME>? After all, this just adds
#pod another layer of stuff around those. Wouldn't using them directly be better?
#pod
#pod Certainly, if you know EXACTLY what you are doing. The docs are clear enough,
#pod but you really do need to have an understanding of the structure of MIME
#pod emails. This structure is going to be different depending on whether you have
#pod text body, HTML, both, with or without an attachment etc.
#pod
#pod Then there's brevity... compare the following roughly equivalent code.
#pod
#pod First, the Email::Stuffer way.
#pod
#pod   Email::Stuffer->to('Simon Cozens<simon@somewhere.jp>')
#pod                 ->from('Santa@northpole.org')
#pod                 ->text_body("You've been good this year. No coal for you.")
#pod                 ->attach_file('choochoo.gif')
#pod                 ->send;
#pod
#pod And now doing it directly with a knowledge of what your attachment is, and
#pod what the correct MIME structure is.
#pod
#pod   use Email::MIME;
#pod   use Email::Sender::Simple;
#pod   use IO::All;
#pod   
#pod   Email::Sender::Simple->try_to_send(
#pod     Email::MIME->create(
#pod       header => [
#pod           To => 'simon@somewhere.jp',
#pod           From => 'santa@northpole.org',
#pod       ],
#pod       parts => [
#pod           Email::MIME->create(
#pod             body => "You've been a good boy this year. No coal for you."
#pod           ),
#pod           Email::MIME->create(
#pod             body => io('choochoo.gif'),
#pod             attributes => {
#pod                 filename => 'choochoo.gif',
#pod                 content_type => 'image/gif',
#pod             },
#pod          ),
#pod       ],
#pod     );
#pod   );
#pod
#pod Again, if you know MIME well, and have the patience to manually code up
#pod the L<Email::MIME> structure, go do that, if you really want to.
#pod
#pod Email::Stuffer as the name suggests, solves one case and one case only:
#pod generate some stuff, and email it to somewhere, as conveniently as
#pod possible. DWIM, but do it as thinly as possible and use the solid
#pod Email:: modules underneath.
#pod
#pod =head1 COOKBOOK
#pod
#pod Here is another example (maybe plural later) of how you can use
#pod Email::Stuffer's brevity to your advantage.
#pod
#pod =head2 Custom Alerts
#pod
#pod   package SMS::Alert;
#pod   use base 'Email::Stuffer';
#pod   
#pod   sub new {
#pod     shift()->SUPER::new(@_)
#pod            ->from('monitor@my.website')
#pod            # Of course, we could have pulled these from
#pod            # $MyConfig->{support_tech} or something similar.
#pod            ->to('0416181595@sms.gateway')
#pod            ->transport('SMTP', { host => '123.123.123.123' });
#pod   }
#pod
#pod Z<>
#pod
#pod   package My::Code;
#pod
#pod   unless ( $Server->restart ) {
#pod           # Notify the admin on call that a server went down and failed
#pod           # to restart.
#pod           SMS::Alert->subject("Server $Server failed to restart cleanly")
#pod                     ->send;
#pod   }
#pod
#pod =head1 METHODS
#pod
#pod As you can see from the synopsis, all methods that B<modify> the
#pod Email::Stuffer object returns the object, and thus most normal calls are
#pod chainable.
#pod
#pod However, please note that C<send>, and the group of methods that do not
#pod change the Email::Stuffer object B<do not> return the object, and thus
#pod B<are not> chainable.
#pod
#pod =cut

use 5.005;
use strict;
use Carp                   qw(croak);
use File::Basename         ();
use Params::Util 1.05      qw(_INSTANCE _INSTANCEDOES);
use Email::MIME            ();
use Email::MIME::Creator   ();
use Email::Sender::Simple  ();

#####################################################################
# Constructor and Accessors

#pod =method new
#pod
#pod Creates a new, empty, Email::Stuffer object.
#pod
#pod =cut

sub new {
	my $class = ref $_[0] || $_[0];

	my $self = bless {
		parts      => [],
		email      => Email::MIME->create(
			header => [],
			parts  => [],
			),
		}, $class;

	$self;
}

sub _self {
	my $either = shift;
	ref($either) ? $either : $either->new;
}

#pod =method header_names
#pod
#pod Returns, as a list, all of the headers currently set for the Email
#pod For backwards compatibility, this method can also be called as B[headers].
#pod
#pod =cut

sub header_names {
	shift()->{email}->header_names;
}

sub headers {
	shift()->{email}->header_names; ## This is now header_names, headers is depreciated
}

#pod =method parts
#pod
#pod Returns, as a list, the L<Email::MIME> parts for the Email
#pod
#pod =cut

sub parts {
	grep { defined $_ } @{shift()->{parts}};
}

#####################################################################
# Header Methods

#pod =method header $header => $value
#pod
#pod Sets a named header in the email. Multiple calls with the same $header
#pod will overwrite previous calls $value.
#pod
#pod =cut

sub header {
	my $self = shift()->_self;
	return unless @_;
	$self->{email}->header_str_set(ucfirst shift, shift);
	return $self;
}

#pod =method to $address
#pod
#pod Sets the To: header in the email
#pod
#pod =cut

sub to {
	my $self = shift()->_self;
	$self->{email}->header_str_set(To => join(q{, }, @_)) ? $self : undef;
}

#pod =method from $address
#pod
#pod Sets the From: header in the email
#pod
#pod =cut

sub from {
	my $self = shift()->_self;
	$self->{email}->header_str_set(From => shift) ? $self : undef;
}

#pod =method cc $address
#pod
#pod Sets the Cc: header in the email
#pod
#pod =cut

sub cc {
	my $self = shift()->_self;
	$self->{email}->header_str_set(Cc => join(q{, }, @_)) ? $self : undef;
}

#pod =method bcc $address
#pod
#pod Sets the Bcc: header in the email
#pod
#pod =cut

sub bcc {
	my $self = shift()->_self;
	$self->{email}->header_str_set(Bcc => join(q{, }, @_)) ? $self : undef;
}

#pod =method subject $text
#pod
#pod Sets the Subject: header in the email
#pod
#pod =cut

sub subject {
	my $self = shift()->_self;
	$self->{email}->header_str_set(Subject => shift) ? $self : undef;
}

#####################################################################
# Body and Attachments

#pod =method text_body $body [, $header => $value, ... ]
#pod
#pod Sets the text body of the email. Unless specified, all the appropriate
#pod headers are set for you. You may override any as needed. See
#pod L<Email::MIME> for the actual headers to use.
#pod
#pod If C<$body> is undefined, this method will do nothing.
#pod
#pod =cut

sub text_body {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return $self;
	my %attr = (
		# Defaults
		content_type => 'text/plain',
		charset      => 'utf-8',
		encoding     => 'quoted-printable',
		format       => 'flowed',
		# Params overwrite them
		@_,
		);

	# Create the part in the text slot
	$self->{parts}->[0] = Email::MIME->create(
		attributes => \%attr,
		body_str   => $body,
		);

	$self;
}

#pod =method html_body $body [, $header => $value, ... ]
#pod
#pod Set the HTML body of the email. Unless specified, all the appropriate
#pod headers are set for you. You may override any as needed. See
#pod L<Email::MIME> for the actual headers to use.
#pod
#pod If C<$body> is undefined, this method will do nothing.
#pod
#pod =cut

sub html_body {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return $self;
	my %attr = (
		# Defaults
		content_type => 'text/html',
		charset      => 'utf-8',
		encoding     => 'quoted-printable',
		# Params overwrite them
		@_,
		);

	# Create the part in the HTML slot
	$self->{parts}->[1] = Email::MIME->create(
		attributes => \%attr,
		body_str   => $body,
		);

	$self;
}

#pod =method attach $contents [, $header => $value, ... ]
#pod
#pod Adds an attachment to the email. The first argument is the file contents
#pod followed by (as for text_body and html_body) the list of headers to use.
#pod Email::Stuffer should TRY to guess the headers right, but you may wish
#pod to provide them anyway to be sure. Encoding is Base64 by default.
#pod
#pod =cut

sub _detect_content_type {
	my ($filename, $body) = @_;

	if (defined($filename)) {
		if ($filename =~ /\.([a-z]{3,4})\z/) {
			my $content_type = {
				'gif'  => 'image/gif',
				'png'  => 'image/png',
				'jpg'  => 'image/jpeg',
				'jpeg' => 'image/jpeg',
				'txt'  => 'text/plain',
				'htm'  => 'text/html',
				'html' => 'text/html',
				'css'  => 'text/css',
			}->{$1};
			return $content_type if defined $content_type;
		}
	}
	if ($body =~ /
		\A(?:
		    (GIF8)          # gif
		  | (\xff\xd8)      # jpeg
		  | (\x89PNG)       # png
		)
	/x) {
		return 'image/gif'  if $1;
		return 'image/jpeg' if $2;
		return 'image/png'  if $3;
	}
	return 'application/octet-stream';
}

sub attach {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return undef;
	my %attr = (
		# Cheap defaults
		encoding => 'base64',
		# Params overwrite them
		@_,
		);

	# The more expensive defaults if needed
	unless ( $attr{content_type} ) {
		$attr{content_type} = _detect_content_type($attr{filename}, $body);
	}

	### MORE?

	# Determine the slot to put it at
	my $slot = scalar @{$self->{parts}};
	$slot = 3 if $slot < 3;

	# Create the part in the attachment slot
	$self->{parts}->[$slot] = Email::MIME->create(
		attributes => \%attr,
		body       => $body,
		);

	$self;
}

#pod =method attach_file $file [, $header => $value, ... ]
#pod
#pod Attachs a file that already exists on the filesystem to the email. 
#pod C<attach_file> will auto-detect the MIME type, and use the file's
#pod current name when attaching.
#pod
#pod =cut

sub attach_file {
	my $self = shift;
	my $body_arg = shift;
	my $name = undef;
	my $body = undef;

	# Support IO::All::File arguments
	if ( Params::Util::_INSTANCE($body_arg, 'IO::All::File') ) {
		$name = $body_arg->name;
		$body = $body_arg->all;

	# Support file names
	} elsif ( defined $body_arg and Params::Util::_STRING($body_arg) ) {
		croak "No such file '$body_arg'" unless -f $body_arg;
		$name = $body_arg;
		$body = _slurp( $body_arg );

	# That's it
	} else {
		my $type = ref($body_arg) || "<$body_arg>";
		croak "Expected a file name or an IO::All::File derivative, got $type";
	}

	# Clean the file name
	$name = File::Basename::basename($name);

	croak("basename somehow returned undef") unless defined $name;

	# Now attach as normal
	$self->attach( $body, name => $name, filename => $name, @_ );
}

# Provide a simple _slurp implementation
sub _slurp {
	my $file = shift;
	local $/ = undef;

	open my $slurp, '<:raw', $file or croak("error opening $file: $!");
	my $source = <$slurp>;
	close( $slurp ) or croak "error after slurping $file: $!";
	\$source;
}

#pod =method transport
#pod
#pod   $stuffer->transport( $moniker, @options )
#pod
#pod or
#pod
#pod   $stuffer->transport( $transport_obj )
#pod
#pod The C<transport> method specifies the L<Email::Sender> transport that
#pod you want to use to send the email, and any options that need to be
#pod used to instantiate the transport.  C<$moniker> is used as the transport
#pod name; if it starts with an equals sign (C<=>) then the text after the
#pod sign is used as the class.  Otherwise, the text is prepended by
#pod C<Email::Sender::Transport::>.  In neither case will a module be
#pod automatically loaded.
#pod
#pod Alternatively, you can pass a complete transport object (which must be
#pod an L<Email::Sender::Transport> object) and it will be used as is.
#pod
#pod =cut

sub transport {
	my $self = shift;

	if ( @_ ) {
		# Change the transport
		if ( _INSTANCEDOES($_[0], 'Email::Sender::Transport') ) {
			$self->{transport} = shift;
		} else {
		  my ($moniker, @arg) = @_;
		  my $class = $moniker =~ s/\A=//
		            ? $moniker
		            : "Email::Sender::Transport::$moniker";
			my $transport = $class->new(@arg);
			$self->{transport} = $transport;
		}
	}

	$self;
}

#####################################################################
# Output Methods

#pod =method email
#pod
#pod Creates and returns the full L<Email::MIME> object for the email.
#pod
#pod =cut

sub email {
	my $self  = shift;
	my @parts = $self->parts;

        ### Lyle Hopkins, code added to Fix single part, and multipart/alternative problems
        if ( scalar( @{ $self->{parts} } ) >= 3 ) {
                ## multipart/mixed
                $self->{email}->parts_set( \@parts );
        }
        ## Check we actually have any parts
        elsif ( scalar( @{ $self->{parts} } ) ) {
                if ( _INSTANCE($parts[0], 'Email::MIME') && _INSTANCE($parts[1], 'Email::MIME') ) {
                        ## multipart/alternate
                        $self->{email}->header_set( 'Content-Type' => 'multipart/alternative' );
                        $self->{email}->parts_set( \@parts );
                }
                ## As @parts is $self->parts without the blanks, we only need check $parts[0]
                elsif ( _INSTANCE($parts[0], 'Email::MIME') ) {
                        ## single part text/plain
                        _transfer_headers( $self->{email}, $parts[0] );
                        $self->{email} = $parts[0];
                }
        }

	$self->{email};
}

# Support coercion to an Email::MIME
sub __as_Email_MIME { shift()->email }

# Quick any routine
sub _any (&@) {
        my $f = shift;
        return if ! @_;
        for (@_) {
                return 1 if $f->();
        }
        return 0;
}

# header transfer from one object to another
sub _transfer_headers {
        # $_[0] = from, $_[1] = to
        my @headers_move = $_[0]->header_names;
        my @headers_skip = $_[1]->header_names;
        foreach my $header_name (@headers_move) {
                next if _any { $_ eq $header_name } @headers_skip;
                my @values = $_[0]->header($header_name);
                $_[1]->header_str_set( $header_name, @values );
        }
}

#pod =method as_string
#pod
#pod Returns the string form of the email. Identical to (and uses behind the
#pod scenes) Email::MIME-E<gt>as_string.
#pod
#pod =cut

sub as_string {
	shift()->email->as_string;
}

#pod =method send
#pod
#pod Sends the email via L<Email::Sender::Simple>.
#pod
#pod On failure, returns false.
#pod
#pod =cut

sub send {
	my $self = shift;
	my $arg  = shift;
	my $email = $self->email or return undef;

	my $transport = $self->{transport};

	Email::Sender::Simple->try_to_send(
	  $email,
	  {
      ($transport ? (transport => $transport) : ()),
      $arg ? %$arg : (),
    },
  );
}

#pod =method send_or_die
#pod
#pod Sends the email via L<Email::Sender::Simple>.
#pod
#pod On failure, throws an exception.
#pod
#pod =cut

sub send_or_die {
	my $self = shift;
	my $arg  = shift;
	my $email = $self->email or return undef;

	my $transport = $self->{transport};

	Email::Sender::Simple->send(
	  $email,
	  {
      ($transport ? (transport => $transport) : ()),
      $arg ? %$arg : (),
    },
  );
}

1;

#pod =head1 TO DO
#pod
#pod =for :list
#pod * Fix a number of bugs still likely to exist
#pod * Write more tests.
#pod * Add any additional small bit of automation that isn't too expensive
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Email::MIME>, L<Email::Sender>, L<http://ali.as/>
#pod
#pod =cut

__END__

=pod

=encoding UTF-8

=head1 NAME

Email::Stuffer - A more casual approach to creating and sending Email:: emails

=head1 VERSION

version 0.010

=head1 SYNOPSIS

  # Prepare the message
  my $body = <<'AMBUSH_READY';
  Dear Santa
  
  I have killed Bun Bun.
  
  Yes, I know what you are thinking... but it was actually a total accident.
  
  I was in a crowded line at a BayWatch signing, and I tripped, and stood on
  his head.
  
  I know. Oops! :/
  
  So anyways, I am willing to sell you the body for $1 million dollars.
  
  Be near the pinhole to the Dimension of Pain at midnight.
  
  Alias

  AMBUSH_READY
  
  # Create and send the email in one shot
  Email::Stuffer->from     ('cpan@ali.as'             )
                ->to       ('santa@northpole.org'     )
                ->bcc      ('bunbun@sluggy.com'       )
                ->text_body($body                     )
                ->attach_file('dead_bunbun_faked.gif' )
                ->send;

=head1 DESCRIPTION

B<The basics should all work, but this module is still subject to
name and/or API changes>

Email::Stuffer, as its name suggests, is a fairly casual module used
to stuff things into an email and send them. It is a high-level module
designed for ease of use when doing a very specific common task, but
implemented on top of the light and tolerable Email:: modules.

Email::Stuffer is typically used to build emails and send them in a single
statement, as seen in the synopsis. And it is certain only for use when
creating and sending emails. As such, it contains no email parsing
capability, and little to no modification support.

To re-iterate, this is very much a module for those "slap it together and
fire it off" situations, but that still has enough grunt behind the scenes
to do things properly.

=head2 Default Transport

Although it cannot be relied upon to work, the default behaviour is to
use C<sendmail> to send mail, if you don't provide the mail send channel
with either the C<transport> method, or as an argument to C<send>.

(Actually, the choice of default is delegated to
L<Email::Sender::Simple>, which makes its own choices.  But usually, it
uses C<sendmail>.)

=head2 Why use this?

Why not just use L<Email::Simple> or L<Email::MIME>? After all, this just adds
another layer of stuff around those. Wouldn't using them directly be better?

Certainly, if you know EXACTLY what you are doing. The docs are clear enough,
but you really do need to have an understanding of the structure of MIME
emails. This structure is going to be different depending on whether you have
text body, HTML, both, with or without an attachment etc.

Then there's brevity... compare the following roughly equivalent code.

First, the Email::Stuffer way.

  Email::Stuffer->to('Simon Cozens<simon@somewhere.jp>')
                ->from('Santa@northpole.org')
                ->text_body("You've been good this year. No coal for you.")
                ->attach_file('choochoo.gif')
                ->send;

And now doing it directly with a knowledge of what your attachment is, and
what the correct MIME structure is.

  use Email::MIME;
  use Email::Sender::Simple;
  use IO::All;
  
  Email::Sender::Simple->try_to_send(
    Email::MIME->create(
      header => [
          To => 'simon@somewhere.jp',
          From => 'santa@northpole.org',
      ],
      parts => [
          Email::MIME->create(
            body => "You've been a good boy this year. No coal for you."
          ),
          Email::MIME->create(
            body => io('choochoo.gif'),
            attributes => {
                filename => 'choochoo.gif',
                content_type => 'image/gif',
            },
         ),
      ],
    );
  );

Again, if you know MIME well, and have the patience to manually code up
the L<Email::MIME> structure, go do that, if you really want to.

Email::Stuffer as the name suggests, solves one case and one case only:
generate some stuff, and email it to somewhere, as conveniently as
possible. DWIM, but do it as thinly as possible and use the solid
Email:: modules underneath.

=head1 METHODS

=head2 new

Creates a new, empty, Email::Stuffer object.

=head2 header_names

Returns, as a list, all of the headers currently set for the Email
For backwards compatibility, this method can also be called as B[headers].

=head2 parts

Returns, as a list, the L<Email::MIME> parts for the Email

=head2 header $header => $value

Sets a named header in the email. Multiple calls with the same $header
will overwrite previous calls $value.

=head2 to $address

Sets the To: header in the email

=head2 from $address

Sets the From: header in the email

=head2 cc $address

Sets the Cc: header in the email

=head2 bcc $address

Sets the Bcc: header in the email

=head2 subject $text

Sets the Subject: header in the email

=head2 text_body $body [, $header => $value, ... ]

Sets the text body of the email. Unless specified, all the appropriate
headers are set for you. You may override any as needed. See
L<Email::MIME> for the actual headers to use.

If C<$body> is undefined, this method will do nothing.

=head2 html_body $body [, $header => $value, ... ]

Set the HTML body of the email. Unless specified, all the appropriate
headers are set for you. You may override any as needed. See
L<Email::MIME> for the actual headers to use.

If C<$body> is undefined, this method will do nothing.

=head2 attach $contents [, $header => $value, ... ]

Adds an attachment to the email. The first argument is the file contents
followed by (as for text_body and html_body) the list of headers to use.
Email::Stuffer should TRY to guess the headers right, but you may wish
to provide them anyway to be sure. Encoding is Base64 by default.

=head2 attach_file $file [, $header => $value, ... ]

Attachs a file that already exists on the filesystem to the email. 
C<attach_file> will auto-detect the MIME type, and use the file's
current name when attaching.

=head2 transport

  $stuffer->transport( $moniker, @options )

or

  $stuffer->transport( $transport_obj )

The C<transport> method specifies the L<Email::Sender> transport that
you want to use to send the email, and any options that need to be
used to instantiate the transport.  C<$moniker> is used as the transport
name; if it starts with an equals sign (C<=>) then the text after the
sign is used as the class.  Otherwise, the text is prepended by
C<Email::Sender::Transport::>.  In neither case will a module be
automatically loaded.

Alternatively, you can pass a complete transport object (which must be
an L<Email::Sender::Transport> object) and it will be used as is.

=head2 email

Creates and returns the full L<Email::MIME> object for the email.

=head2 as_string

Returns the string form of the email. Identical to (and uses behind the
scenes) Email::MIME-E<gt>as_string.

=head2 send

Sends the email via L<Email::Sender::Simple>.

On failure, returns false.

=head2 send_or_die

Sends the email via L<Email::Sender::Simple>.

On failure, throws an exception.

=head1 COOKBOOK

Here is another example (maybe plural later) of how you can use
Email::Stuffer's brevity to your advantage.

=head2 Custom Alerts

  package SMS::Alert;
  use base 'Email::Stuffer';
  
  sub new {
    shift()->SUPER::new(@_)
           ->from('monitor@my.website')
           # Of course, we could have pulled these from
           # $MyConfig->{support_tech} or something similar.
           ->to('0416181595@sms.gateway')
           ->transport('SMTP', { host => '123.123.123.123' });
  }

Z<>

  package My::Code;

  unless ( $Server->restart ) {
          # Notify the admin on call that a server went down and failed
          # to restart.
          SMS::Alert->subject("Server $Server failed to restart cleanly")
                    ->send;
  }

=head1 METHODS

As you can see from the synopsis, all methods that B<modify> the
Email::Stuffer object returns the object, and thus most normal calls are
chainable.

However, please note that C<send>, and the group of methods that do not
change the Email::Stuffer object B<do not> return the object, and thus
B<are not> chainable.

=head1 TO DO

=over 4

=item *

Fix a number of bugs still likely to exist

=item *

Write more tests.

=item *

Add any additional small bit of automation that isn't too expensive

=back

=head1 SEE ALSO

L<Email::MIME>, L<Email::Sender>, L<http://ali.as/>

=head1 AUTHORS

=over 4

=item *

Adam Kennedy <adamk@cpan.org>

=item *

Ricardo SIGNES <rjbs@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Adam Kennedy and Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

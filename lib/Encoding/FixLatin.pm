package Encoding::FixLatin;

use warnings;
use strict;

require 5.008;

our $VERSION = '1.00';

use Carp     qw(croak);
use Exporter qw(import);

our @EXPORT_OK = qw(fix_latin);


my $byte_map;

my $ascii_char = '[\x00-\x7F]';
my $cont_byte  = '[\x80-\xBF]';

my $utf8_2     = '[\xC0-\xDF]' . $cont_byte;
my $utf8_3     = '[\xE0-\xEF]' . $cont_byte . '{2}';
my $utf8_4     = '[\xF0-\xF7]' . $cont_byte . '{3}';
my $utf8_5     = '[\xF8-\xFB]' . $cont_byte . '{4}';

my $nibble_good_chars = qr{^($ascii_char+|$utf8_2|$utf8_3|$utf8_4|$utf8_5)(.*)$}s;

my %known_opt = map { $_ => 1 } qw(bytes_only);

sub fix_latin {
    my $input = shift;
    my %opt   = @_;

    foreach (keys %opt) {
        croak "Unknown option '$_'" unless $known_opt{$_};
    }

    return unless defined($input);
    _init_byte_map() unless $byte_map;

    my $output = '';
    my $char   = '';
    my $rest   = '';
    while(length($input) > 0) {
        if(($char, $rest) = $input =~ $nibble_good_chars) {
            $output .= $char;
        }
        else {
            ($char, $rest) = $input =~ /^(.)(.*)$/s;
            $output .= $byte_map->{$char};
        }
        $input = $rest;
    }
    utf8::decode($output) unless $opt{bytes_only};
    return $output;
}


sub _init_byte_map {
    foreach my $i (0x80..0xFF) {
        my $utf_char = chr($i);
        utf8::encode($utf_char);
        $byte_map->{pack('C', $i)} = $utf_char;
    }
    _add_cp1252_mappings();
}


sub _add_cp1252_mappings {
    # From http://unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT
    my %ms_map = (
        "\x80" => "\xE2\x82\xAC",  # EURO SIGN
        "\x82" => "\xE2\x80\x9A",  # SINGLE LOW-9 QUOTATION MARK
        "\x83" => "\xC6\x92",      # LATIN SMALL LETTER F WITH HOOK
        "\x84" => "\xE2\x80\x9E",  # DOUBLE LOW-9 QUOTATION MARK
        "\x85" => "\xE2\x80\xA6",  # HORIZONTAL ELLIPSIS
        "\x86" => "\xE2\x80\xA0",  # DAGGER
        "\x87" => "\xE2\x80\xA1",  # DOUBLE DAGGER
        "\x88" => "\xCB\x86",      # MODIFIER LETTER CIRCUMFLEX ACCENT
        "\x89" => "\xE2\x80\xB0",  # PER MILLE SIGN
        "\x8A" => "\xC5\xA0",      # LATIN CAPITAL LETTER S WITH CARON
        "\x8B" => "\xE2\x80\xB9",  # SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        "\x8C" => "\xC5\x92",      # LATIN CAPITAL LIGATURE OE
        "\x8E" => "\xC5\xBD",      # LATIN CAPITAL LETTER Z WITH CARON
        "\x91" => "\xE2\x80\x98",  # LEFT SINGLE QUOTATION MARK
        "\x92" => "\xE2\x80\x99",  # RIGHT SINGLE QUOTATION MARK
        "\x93" => "\xE2\x80\x9C",  # LEFT DOUBLE QUOTATION MARK
        "\x94" => "\xE2\x80\x9D",  # RIGHT DOUBLE QUOTATION MARK
        "\x95" => "\xE2\x80\xA2",  # BULLET
        "\x96" => "\xE2\x80\x93",  # EN DASH
        "\x97" => "\xE2\x80\x94",  # EM DASH
        "\x98" => "\xCB\x9C",      # SMALL TILDE
        "\x99" => "\xE2\x84\xA2",  # TRADE MARK SIGN
        "\x9A" => "\xC5\xA1",      # LATIN SMALL LETTER S WITH CARON
        "\x9B" => "\xE2\x80\xBA",  # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
        "\x9C" => "\xC5\x93",      # LATIN SMALL LIGATURE OE
        "\x9E" => "\xC5\xBE",      # LATIN SMALL LETTER Z WITH CARON
        "\x9F" => "\xC5\xB8",      # LATIN CAPITAL LETTER Y WITH DIAERESIS
    );
    while(my($k, $v) = each %ms_map) {
        $byte_map->{$k} = $v;
    }
}


1;

__END__

=head1 NAME

Encoding::FixLatin - takes mixed encoding input and produces UTF-8 output


=head1 SYNOPSIS

    use Encoding::FixLatin qw(fix_latin);

    my $utf8_string = fix_latin($mixed_encoding_string);


=head1 DESCRIPTION

Most encoding conversion tools take input in one encoding and produce output in
another encoding.  This module takes input which may contain characters in more
than one encoding and makes a best effort to convert them all to UTF-8 output.


=head1 EXPORTS

Nothing is exported by default.  The only public function is C<fix_latin> which
will be exported on request (as per SYNOPSIS).


=head1 FUNCTIONS

=head2 fix_latin( string, options ... )

Decodes the supplied 'string' and returns a UTF-8 version of the string.  The
following rules are used:

=over 4

=item *

ASCII characters (single bytes in the range 0x00 - 0x7F) are passed through
unchanged.

=item *

Well-formed UTF-8 multi-byte characters are also passed through unchanged.

=item *

Bytes in the range 0xA0 - 0xFF are assumed to be Latin-1 characters (ISO8859-1
encoded) and are converted to UTF-8.

=item *

Bytes in the range 0x80 - 0x9F are assumed to be Win-Latin-1 characters (CP1252 encoded) and are converted to UTF-8.

=back

The achilles heel of these rules is that it's possible for certain combinations
of two consecutive Latin-1 characters to be misinterpreted as a single UTF-8
character - ie: there is some risk of data corruption.  See the 'LIMITATIONS'
section below to quantify this risk for the type of data you're working with.

If you pass in a string that already has the 'utf8' flag set then C<fix_latin>
will simply return the string immediately.

The C<fix_latin> function accepts options as name => value pairs.  Currently
only one option is recognised:

=over 4

=item bytes_only => 1/0

The value returned by fix_latin is normally a Perl character string and will
have the utf8 flag set if it contains non-ASCII characters.  If you set the
C<bytes_only> option to a true value, the returned string will be a binary
string of UTF-8 bytes.  The utf8 flag will not be set.  This is useful if
you're going to immediately use the string in an IO operation and wish to avoid
the overhead of converting to and from Perl's internal representation.

As mentioned above, strings that already have the 'utf8' flag set are always
returned unaltered.  They will be returned in their original character string
form regardless of the value of the 'bytes_only' option.  If you really want
to convert a character string to UTF-8 bytes then you could use the
C<encode_utf8> function from the Encode module (or just push the :utf8 layer
onto your IO file handle with C<binmode>).

=back

=head1 LIMITATIONS OF THIS MODULE

This module is perfectly safe when handling data containing only ASCII and
UTF-8 characters.  Introducing ISO8859-1 or CP1252 characters does add a risk
of data corruption (ie: some characters in the input being converted to
incorrect characters in the output).  To quantify the risk it is necessary to
understand it's cause.  First, let's break the input bytes into two categories.

=over 4

=item *

ASCII bytes fall into the range 0x00-0x7F - the most significant bit is always
set to zero.  I'll use the symbol 'a' to represent these bytes.

=item *

Non-ASCII bytes fall into the range 0x80-0xFF - the most significant bit is
always set to one.  I'll use the symbol 'B' to represent these bytes.

=back

A sequence of ASCII bytes ('aaa') is always unambiguous and will not be
misinterpreted.

Lone non-ASCII bytes within sequences of ASCII bytes ('aaBaBa') are also
unambiguous and will not be misinterpreted.

The potential for error occurs with two (or more) consecutive non-ASCII bytes.
For example the sequence 'BB' might be intended to represent two characters in
one of the legacy encodings or a single character in UTF-8.  Because this
module gives precedence to the UTF-8 characters it is possible that a random
pair of legacy characters may be misinterpreted as a single UTF-8 character.

The risk is reduced by the fact that not all pairs of non-ASCII bytes form
valid UTF-8 sequences.  Every non-ASCII UTF-8 character is made up of two or
more 'B' bytes and no 'a' bytes.  For a two-byte character, the first byte must
be in the range 0xC0-0xDF and the second must be in the range 0x80-0xBF.

Any pair of 'BB' bytes that do not fall into the required ranges are
unambiguous and will not be misinterpreted.

Pairs of 'BB' bytes that are actually individual Latin-1 characters but
happen to fall into the required ranges to be misinterpreted as a UTF-8
character are rather unlikely to appear in normal text.  If you look those
ranges up on a Latin-1 code chart you'll see that the first character would
need to be an uppercase accented letter and the second  would need to be a
non-printable control character or a special punctuation symbol.

One way to summarise the role of this module is that it guarantees to
produce UTF-8 output, possibly at the cost of introducing the odd 'typo'.


=head1 BUGS

Please report any bugs to C<bug-encoding-fixlatin at rt.cpan.org>, or through
the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Encoding-FixLatin>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.


=head1 SUPPORT

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Encoding-FixLatin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Encoding-FixLatin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Encoding-FixLatin>

=item * Search CPAN

L<http://search.cpan.org/dist/Encoding-FixLatin/>

=back


=head1 AUTHOR

Grant McLean, C<< <grantm at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright 2009 Grant McLean

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


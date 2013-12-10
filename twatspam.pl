# == WHAT
# Expand the tweets mentioned in a channel, as well as the tweets those tweets refer to.
#
# == WHO
# Jan Moesen, 2012–2013
#
# == INSTALL
# Save it in ~/.irssi/scripts/ and do /script load twatspam.pl
# OR
# Save it in ~/.irssi/scripts/autorun and (re)start Irssi

use strict;
use utf8;
use Irssi;
use Net::Twitter;
use Time::HiRes 'usleep';
use vars qw($VERSION %IRSSI);

$VERSION = '0.2';
%IRSSI = (
	authors     => 'Jan Moesen',
	name        => 'Twatspam',
	description => 'Expand the tweets mentioned in a channel, as well as the tweets those tweets refer to.',
	license     => 'GPL',
	url         => 'http://jan.moesen.nu/',
);

my $twitter;

sub twatspam_load {
	# Get these from https://dev.twitter.com/apps/new
	Irssi::settings_add_str('twatspam', 'twatspam_consumer_key', '');
	Irssi::settings_add_str('twatspam', 'twatspam_consumer_secret', '');
	Irssi::settings_add_str('twatspam', 'twatspam_access_token', '');
	Irssi::settings_add_str('twatspam', 'twatspam_access_token_secret', '');

	$twitter = Net::Twitter->new(
		traits              => [qw/API::RESTv1_1 WrapError/],
		decode_html_entities => 1,
		consumer_key        => Irssi::settings_get_str('twatspam_consumer_key'),
		consumer_secret     => Irssi::settings_get_str('twatspam_consumer_secret'),
		access_token        => Irssi::settings_get_str('twatspam_access_token'),
		access_token_secret => Irssi::settings_get_str('twatspam_access_token_secret'),
	);
}

twatspam_load();
Irssi::signal_add('setup changed', \&twatspam_load);

sub twatspam_process_message {
	my ($server, $msg, $target) = @_;

	return unless $target =~ /^#(fronteers|catena|lolwut)/;
	return unless $msg =~ m/https?:\/\/(?:favstar\.fm|twitter\.com|mobile\.twitter\.com)\/.*\/status(?:es)?\/(\d+)(?:.*)?$/;

	my $status_id = $1;

	return unless my $tweet = $twitter->show_status($status_id);

	# Expand link and media URLs.
	my $text = $tweet->{text};
	foreach my $entity (@{$tweet->{entities}->{urls}}, @{$tweet->{entities}->{media}}) {
		my $old_url = quotemeta($entity->{url});
		my $new_url = $entity->{expanded_url};
		$text =~ s/$old_url/$new_url/g;
		$text =~ s/\r/ /g;
		$text =~ s/\n/ \/\/ /g;
	}

	my $message = "Tweet by \@$tweet->{user}->{screen_name} ($tweet->{user}->{name}): \"$text\"";

	# Prevent infinite loops.
	utf8::decode($msg);
	return if ($message eq $msg);

	my $isInReplyTo = $tweet->{in_reply_to_screen_name} && $tweet->{in_reply_to_status_id};
	if ($isInReplyTo && $msg !~ /!expand/) {
		$message .= ' (Twatspam tip: append "!expand" to show the context.)';
	}

	$server->command("msg $target $message");

	if ($isInReplyTo && $msg =~ /!expand/) {
		$server->command("msg $target ↳ In reply to: https://twitter.com/$tweet->{in_reply_to_screen_name}/status/$tweet->{in_reply_to_status_id} !expand");
		usleep(25000);
	}
}

Irssi::signal_add_last('message public', sub {
	my ($server, $msg, $nick, $mask, $target) = @_;
	Irssi::signal_continue($server, $msg, $nick, $mask, $target);
	twatspam_process_message($server, $msg, $target);
});
Irssi::signal_add_last('message own_public', sub {
	my ($server, $msg, $target) = @_;
	Irssi::signal_continue($server, $msg, $target);
	twatspam_process_message($server, $msg, $target);
});

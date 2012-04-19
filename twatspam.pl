# == WHAT
# Expand the tweets mentioned in a channel, as well as the tweets those tweets refer to.
#
# == WHO
# Jan Moesen, 2012
#
# == INSTALL
# Place these files in `~/.irssi/scripts/`.
# /script load twatspam.pl

use strict;
use Irssi;
use JSON::XS;
use LWP::Simple;
use Time::HiRes 'usleep';
use vars qw($VERSION %IRSSI);

$VERSION = '0.1';
%IRSSI = (
	authors     => 'Jan Moesen',
	name        => 'Twatspam',
	description => 'Expand the tweets mentioned in a channel, as well as the tweets those tweets refer to.',
	license     => 'GPL',
	url         => 'http://jan.moesen.nu/',
	changed     => 'Thu Apr 19 21:55:07 +0200 2012',
);

sub twatspam_process_message {
	my ($server, $msg, $target) = @_;

	return unless $target =~ /^#(wijs|catena|lolwut)/;
	return unless $msg =~ m/https?:\/\/(?:favstar\.fm|twitter\.com)\/.*\/status\/(\d+)(?:.*)?$/;

	my $status_id = $1;
	my $json_url = "http://api.twitter.com/1/statuses/show/$status_id.json";
	my $json = get($json_url);
	return unless $json;

	my $tweet = decode_json($json);
	my $message = "Tweet by \@$tweet->{user}->{screen_name} ($tweet->{user}->{name}): \"$tweet->{text}\"";

	$server->command("msg $target $message");

	if ($tweet->{in_reply_to_screen_name} && $tweet->{in_reply_to_status_id}) {
		$server->command("msg $target ↳ In reply to: https://twitter.com/$tweet->{in_reply_to_screen_name}/status/$tweet->{in_reply_to_status_id}");
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

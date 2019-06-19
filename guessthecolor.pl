# Guess the color
#
# What is this?
#
# Guess the color is a card game, using one deck (52 cards).
# The basic idea of it is to guess the color of next card
# right. Repeat until guessing wrong or run out of cards.
#
# usage
#
# .top3		Prints out top 3 players with high scores.
# .red		Player guesses a red card (heart or diamond).
# .black	Player guesses a black card (spade or club).
# .score	Returns high score of message sender.
# .score <nick>	Returns high score of a nickname.
#
# Alternatively use legacy !rb prefix:
# !rb top3	Prints out top 3 players with high scores.
# !rb red	Player guesses a red card (heart or diamond).
# !rb black	Player guesses a black card (spade or club).
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);
use Cwd qw();
use DBI;
use IO::File;
use List::Util qw(shuffle);

$VERSION = '0.22';
%IRSSI = (
authors		=> 'Juhani Karppinen',
contact		=> 'jcara',
name		=> 'Guess the color',
description	=> 'A game where a player guesses the colour of the next card.',
license		=> 'GPLv3 or later',
);

my @deck_full = ("Ac", "2c", "3c", "4c", "5c", "6c", "7c", "8c", "9c", "Tc", "Jc", "Qc", "Kc",
"Ad", "2d", "3d", "4d", "5d", "6d", "7d", "8d", "9d", "Td", "Jd", "Qd", "Kd",
"As", "2s", "3s", "4s", "5s", "6s", "7s", "8s", "9s", "Ts", "Js", "Qs", "Ks",
"Ah", "2h", "3h", "4h", "5h", "6h", "7h", "8h", "9h", "Th", "Jh", "Qh", "Kh",
);

# Connect to database
my $dbh = DBI->connect('dbi:SQLite:dbname='.Cwd::abs_path().'/guessthecolor.db', ,'', '',
{AutoCommit=>1,RaiseError=>1,PrintError=>0});

###
# Initiate database tables
###

$dbh->do("CREATE TABLE IF NOT EXISTS players(name TEXT, score INTEGER, count INTEGER)");
$dbh->do("CREATE TABLE IF NOT EXISTS games(name TEXT, deck TEXT)");

# Insert dummy users
$dbh->do("INSERT INTO players(name, score, count) SELECT 'Player 1', 0, 0 WHERE NOT EXISTS(SELECT 1 FROM players WHERE name = 'Player 1')");
$dbh->do("INSERT INTO players(name, score, count) SELECT 'Player 2', 0, 0 WHERE NOT EXISTS(SELECT 1 FROM players WHERE name = 'Player 2')");
$dbh->do("INSERT INTO players(name, score, count) SELECT 'Player 3', 0, 0 WHERE NOT EXISTS(SELECT 1 FROM players WHERE name = 'Player 3')");

sub right_guess {
	my $guessed_card = substr $_[0], 1;
	if ($_[1] eq "black" && ($guessed_card eq "c" || $guessed_card eq "s")) {
		return 1;
	}
	elsif ($_[1] eq "red" && ($guessed_card eq "d" || $guessed_card eq "h")) {
		return 1;
	}
	else {
		return 0;
	}
}

sub red_or_black_filter {
	if (	$_[0] eq 'red' ||
	$_[0] eq '.red'
	) {
		return 'red';
	}
	elsif (	$_[0] eq 'black' ||
	$_[0] eq '.black') {
		return 'black';
	}
	else { return 'invalid'; }
}

sub send_message {
	my $serv = $_[0];
	my $nick = $_[1];
	my $msg = $_[2];
	my $chan = "";
	my $chan = $_[3];

	# Check if the command arrived from query or channel
	if ($chan ne "") {
		$serv->command('msg '.$chan.' '.$msg);
	}
	else {
		$serv->command('msg '.$nick.' '.$msg);
	}

}

sub message_public {
	my ($server, $msg, $nick, $target, $channel) = @_;
	my @channel_whitelist = ('#channel1', '#channel2');

	my $_ = $msg;
	my $sth;
	my @shuffled_deck;
	my $rand_card;
	my @deck;
	my @result;

	if (($channel ~~ @channel_whitelist)
	|| $channel eq ""
	) {
		if (/^(!rb |\.)top3/i) {
			$sth = $dbh->prepare("SELECT name, score FROM players ORDER BY score DESC LIMIT 3");
			my @top3_result = $sth->execute();
			my $top3_str = "";
			my $idx = 1;
			while ( @top3_result = $sth->fetchrow_array ) {
				$top3_str = $top3_str.' '.$idx.'. '.$top3_result[0].' ('.@top3_result[1].') ';
				++$idx;
			}
			send_message($server, $nick, $top3_str, $channel);

		}
		elsif (/^(!rb |\.)(red|black)/i) {
			my @in = split / /, $msg;
			my $input_size = scalar @in;
			my $guesses = 0;

			# Sanitize input and stop executing if not valid
			if ($in[0] =~ /^\.(black|red)/i) {
				$in[1] = red_or_black_filter($in[0]);
			}
			elsif ($input_size < 2) {
				return 0;
			}

			if ($in[1] =~ /^!(black|red)/i) {
				return 0;
			}

			###
			# Check if there's former info about player
			###

			$sth = $dbh->prepare("SELECT name FROM players WHERE name = ?");
			my @player_check = $sth->execute($nick);
			my $rows = 0;
			while(defined(my $r = $sth->fetchrow_arrayref)) {
				++$rows;
			}

			# If the player isn't found in the database, insert
			if ($rows == 0) {
				$sth = $dbh->prepare('INSERT INTO players VALUES (?, ?, ?)');
				$sth->execute($nick, 0, 0);
			}

			###
			# Check for active game of player
			###

			$sth = $dbh->prepare("SELECT name FROM games WHERE name = ?");
			@player_check = $sth->execute($nick);
			$rows = 0;
			while (defined(my $r = $sth->fetchrow_arrayref)) {
				++$rows;
			}

			# If there is no active game found, create one
			if ($rows == 0) {
				@deck = shuffle @deck_full;

				$sth = $dbh->prepare('INSERT INTO games VALUES (?, ?)');
				$sth->execute($nick, "@deck");

			}
			else {
				@result =  $dbh->selectrow_array("SELECT deck FROM games WHERE name = '".$nick."'");
				@deck = split ' ', $result[0]; # split to two character cells in array
				# Do the magic shuffling trick
				@deck = shuffle @deck;
			}

			# Take one card from the deck
			my $card = pop @deck;

			# Check if player guessed it right
			my $guess = red_or_black_filter($in[1]);

			###
			# Check if user guessed the color right.
			###

			my $result = right_guess($card, red_or_black_filter($in[1]));

			if ($result == 1) {
				$guesses = 52 - (scalar @deck);
				my $sth = $dbh->prepare('UPDATE games SET deck = ? WHERE name = ?');
				$sth->execute("@deck", $nick);

				my $msg_str = $nick.': ['.$card.'] Right! Score: '. $guesses;
				send_message($server, $nick, $msg_str, $channel);
			}
			else {
				$guesses = 52 - (scalar @deck) - 1;

				# Reset game status
				my $sth = $dbh->prepare('DELETE FROM games WHERE name = ?');
				$sth->execute($nick);

				my @player_info =  $dbh->selectrow_array("SELECT score, count FROM players WHERE name = '".$nick."'");
				my $personal_best = @player_info[0];
				my $score_notice;

				# Check if player hit the personal best
				if ($guesses > $personal_best) {
					$personal_best = $guesses;
					$score_notice = "Your new personal best!";
				}
				else {
					$score_notice = 'Personal best: '.$personal_best;
				}
				$sth = $dbh->prepare('UPDATE players SET count = ?, score = ? WHERE name = ?');
				$sth->execute($player_info[1] + 1, $personal_best, $nick);
				my $msg_str = $nick.': ['.$card.'] Wrong. Your final score: '. $guesses. '. '.$score_notice;
				send_message($server, $nick, $msg_str, $channel);
			}
		}
		elsif (/^\.score/i) {
			my @in = split / /, $msg;
			my $input_size = scalar @in;
			my $requested_nick;
			if($input_size > 1){
				$requested_nick = $in[1];
			}
			else {
				$requested_nick = $nick;
			}
			my @my_result =  $dbh->selectrow_array("SELECT name, score FROM players WHERE name = '".$requested_nick."' COLLATE NOCASE");
			if(@my_result) {
				my $output_str = "$nick: High score of $my_result[0]: $my_result[1]";
				send_message($server, $nick, $output_str, $channel);
			}
		}
	}
}


signal_add("message public", "message_public");
signal_add("message private", "message_public");

# guessthecolor
An irssi script to deal cards for 'Guess the color' game.

## Usage

| Command | Description |
|---------|-------------|
| `.top3` | Prints out top 3 players with high scores |
| `.red` | Player guesses a red card (heart or diamond) |
| `.black` | Player guesses a black card (spade or club) |
| `.score` | Returns high score of message sender |
| `.score <nick>` | Returns high score of a nickname |

Legacy `!rb` prefix is also supported:

| Command | Description |
|---------|-------------|
| `!rb top3` | Prints out top 3 players with high scores |
| `!rb red` | Player guesses a red card (heart or diamond) |
| `!rb black` | Player guesses a black card (spade or club) |

# Installation instructions

Clone the repository

`mkdir -p ~/.irssi/scripts`
`ln -s guessthecolor.pl ~/.irssi/scripts/guessthecolor.pl`

Install Perl dependencies:
`sudo apt install libdbd-sqlite3-perl`
`cpan -i DBI`


Open `irssi`
`/script load guessthecolor.pl`

## License

This project is open source software licensed under the GNU General Public License v3.0. For more information see [LICENSE](LICENSE).

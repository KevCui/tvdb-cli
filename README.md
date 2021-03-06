# tvdb-cli ![CI](https://github.com/KevCui/tvdb-cli/workflows/CI/badge.svg)

A script to fetch your favorite TV show information from [TheTVDB](https://www.thetvdb.com/) using fast & furious [TheTVDB API v2](https://api.thetvdb.com/swagger#/)

## Dependency

- [cURL](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)
- TheTVDB API key: register to get API key from [TheTVDB site](https://www.thetvdb.com/register)

## How to use

```
Usage:
  ./tvdb.sh [-c|-s|-y <year_range>|-f|-r|-d <date>] <search_text>

Options:
  -c               Filter series status equals to continuing
  -s               Show series only, without episodes list
  -y <year_range>  Filter series first aired in the range of years, like: 2000-2016
  -f               Filter episodes aired in the future
  -d <date>        Filter episodes aired after the date, format like: 1999-12-20
                   -d option overrules -f
  -r               Show IMDb rating and votes per episode
  -h | --help      Display this help message
```

1. Declare API key, user key and user name in terminal:

```
export TVDB_API_KEY="<tvdb_api_key>"
export TVDB_USER_KEY="<tvdb_user_key>"
export TVDB_USER_NAME="<tvdb_username>"
```

Add them to `.zshrc` file if you want to run script in other terms.

2. Run Script:

```
./tvdb.sh <search_text>
```

### Example:

- Show `One-Punch Man` episodes list:

```
~$ ./tvdb.sh one punch man

-----
One-Punch Man
First Aired: 2015-10-04
Status: Continuing
Overview: Saitama is a superhero who has trained so hard that his hair has fallen out, and who can overcome any enemy with one punch. However, because he is so strong, he has become bored and frustrated that he wins all of his battles too easily.
2015-10-04	S1E1	The Strongest Man
2015-10-11	S1E2	The Lone Cyborg
2015-10-18	S1E3	The Obsessive Scientist
2015-10-26	S1E4	The Modern Ninja
2015-11-01	S1E5	The Ultimate Master
2015-11-08	S1E6	The Terrifying City
2015-11-15	S1E7	The Ultimate Disciple
2015-11-22	S1E8	The Deep Sea King
2015-11-29	S1E9	Unyielding Justice
2015-12-06	S1E10	Unparalleled Peril
2015-12-13	S1E11	The Dominator of the Universe
2015-12-20	S1E12	The Strongest Hero
2019-04-10	S2E1	Return of the Hero
2019-04-17	S2E2	Human Monster
2019-04-24	S2E3	The Hunt Begins
2019-05-01	S2E4	The Metal Bat
2019-05-08	S2E5	The Martial Arts Tournament
2019-05-15	S2E6	The Uprising of the Monsters
2019-05-22	S2E7	The Class S Heroes
2019-05-29	S2E8	The Resistance of the Strong
2019-06-12	S2E9	The Ultimate Dilemma
2019-06-19	S2E10	Episode 10
2019-06-26	S2E11	Episode 11
2019-07-03	S2E12	Episode 12
```

- Show `One-Punch Man` series information only, without episodes list:

```
~$ ./tvdb.sh -s one punch man

-----
One-Punch Man
First Aired: 2015-10-04
Status: Continuing
Overview: Saitama is a superhero who has trained so hard that his hair has fallen out, and who can overcome any enemy with one punch. However, because he is so strong, he has become bored and frustrated that he wins all of his battles too easily.
```

- Show `One-Punch Man` episodes list aired in the future (today 2019-06-10):

```
~$ ./tvdb.sh -f one punch man

-----
One-Punch Man
First Aired: 2015-10-04
Status: Continuing
Overview: Saitama is a superhero who has trained so hard that his hair has fallen out, and who can overcome any enemy with one punch. However, because he is so strong, he has become bored and frustrated that he wins all of his battles too easily.

2019-06-12  S2E9   The Ultimate Dilemma
2019-06-19  S2E10  Episode 10
2019-06-26  S2E11  Episode 11
2019-07-03  S2E12  Episode 12
```

- Show `One-Punch Man` episodes list aired after `2019-06-20`:

```
~$ ./tvdb.sh -d 2019-06-20 one punch man

-----
One-Punch Man
First Aired: 2015-10-04
Status: Continuing
Overview: Saitama is a superhero who has trained so hard that his hair has fallen out, and who can overcome any enemy with one punch. However, because he is so strong, he has become bored and frustrated that he wins all of his battles too easily.

2019-06-26  S2E11 Episode 11
2019-07-03  S2E12 Episode 12
```

- Show `Chernobyl` episodes list with IMDb rating:

```
~$ ./tvdb.sh -r chernobyl
-----
Chernobyl
First Aired:
Status: Ended
Overview: Chernobyl dramatizes the story of the 1986 nuclear accident — one of the worst man-made catastrophes in history — and the sacrifices made to save Europe from unimaginable disaster.

2019-05-06  S1E1  1:23:45                       9.6
2019-05-13  S1E2  Please Remain Calm            9.7
2019-05-20  S1E3  Open Wide, O Earth            9.7
2019-05-27  S1E4  The Happiness of All Mankind  9.6
2019-06-03  S1E5  Vichnaya Pamyat               9.9
...
```

- Show `Friends` episodes list, the series first aired in 1994:

```
~$ ./tvdb.sh -y 1994-1995 friends
...
Or
~$ ./tvdb.sh -y 1994 friends
...
```

- Show `Game of Thrones` series which is continuing:

```
~$ ./tvdb.sh -c game of thrones
```

No results? That's right!

## Run tests

```
~$ bats test/tvdb.bats
```

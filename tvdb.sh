#!/usr/bin/env bash
#
# Fetch TV series infomation from tvdb
#
#/ Usage:
#/   ./tvdb.sh [-c|-s|-y <year_range>|-f|-r|-d <date>] <search_text>
#/
#/ Options:
#/   -c               Filter series status equals to continuing
#/   -s               Show series only, without episodes list
#/   -y <year_range>  Filter series first aired in the range of years, like: 2000-2016
#/   -f               Filter episodes aired in the future
#/   -d <date>        Filter episodes aired after the date, format like: 1999-12-20
#/                    -d option overrules -f
#/   -r               Show IMDb rating per episode (attention: it can be slow)
#/   -h | --help      Display this help message
#/
#/ Examples:
#/   \e[32m- Show `One-Punch Man` episodes list:\e[0m
#/     ~$ ./tvdb.sh one punch man
#/
#/   \e[32m- Show `One-Punch Man` series infomation only:\e[0m
#/     ~$ ./tvdb.sh \e[33m-s\e[0m one punch man
#/
#/   \e[32m- Show `One-Punch Man` episodes list with IMDb rating:\e[0m
#/     ~$ ./tvdb.sh \e[33m-r\e[0m one punch man
#/
#/   \e[32m- Show `One-Punch` Man episodes list aired in the future:\e[0m
#/     ~$ ./tvdb.sh \e[33m-f\e[0m one punch man
#/
#/   \e[32m- Show `One-Punch Man` episodes list aired after 2019-06-20:\e[0m
#/     ~$ ./tvdb.sh \e[33m-d 2019-06-20\e[0m one punch man
#/
#/   \e[32m- Show `Friends` episodes list, the series first aired in 1994:\e[0m
#/     ~$ ./tvdb.sh \e[33m-y 1994-1995\e[0m friends
#/     ...
#/     or
#/     ~$ ./tvdb.sh \e[33m-y 1994\e[0m friends
#/     ...
#/
#/   \e[32m- Show `Game of Thrones` series which is still continuing:\e[0m
#/     ~$ ./tvdb.sh \e[33m-c\e[0m game of thrones

set -e
set -u

usage() {
    # Display usage message
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" && exit 0
}

set_var() {
    # Declare variables used in script
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hcfrsd:y:" opt; do
        case $opt in
            s)
                _SHOW_SERIES_ONLY=false
                ;;
            y)
                _YEAR_RANGE_FIRSTAIRED="$OPTARG"
                _MIN_YEAR_FIRSTAIRED=${_YEAR_RANGE_FIRSTAIRED%%-*}
                _MAX_YEAR_FIRSTAIRED=${_YEAR_RANGE_FIRSTAIRED#*-}
                check_firstaired_year_range "$_MIN_YEAR_FIRSTAIRED" "$_MAX_YEAR_FIRSTAIRED"
                ;;
            r)
                _SHOW_RATING=true
                ;;
            d)
                _DATE_AIRED="$OPTARG"
                ;;
            f)
                _FUTURE_AIRED=true
                ;;
            c)
                _CONTINUING_AIRED=true
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done
    shift $((OPTIND-1))

    _SEARCH_TEXT=$( echo "$*" | sed -E 's/ /%20/g')
    _HOST="https://api.thetvdb.com"
    _IMDB_URL="https://www.imdb.com/title"
    _TOKEN_FILE="/tmp/.tvdb.token"
    _TMP_FILE_SERIES="/tmp/.tvdb.tmp.series"
    _TMP_FILE_EPISODES="/tmp/.tvdb.tmp.episodes"
    _TOKEN=""
    _CURL=$(command -v curl) || command_not_found "curl"
    _JQ=$(command -v jq) || command_not_found "jq"

    true > $_TMP_FILE_SERIES
    true > $_TMP_FILE_EPISODES
}

set_api() {
    # Declare vairables according to tvdb APIs
    _API_LOGIN="$_HOST/login"
    _API_REFRESH_TOKEN="$_HOST/refresh_token"
    _API_SEARCH_SERIES="$_HOST/search/series"
    _API_SERIES_EPISODES="$_HOST/series/{id}/episodes"
}

command_not_found() {
    # Show command not found message
    # $1: command name
    printf "%b\n" '\033[31m'"$1"'\033[0m command not found!' && exit 1
}

check_firstaired_year_range() {
    # Check if year range is valid
    # $1: min. year
    # $2: max. year
    if [[ "$1" -gt "$2" ]]; then
        echo "Invalid year range: -y <year_range>!" && usage
    fi
}

check_var() {
    # Check _SEARCH_TEXT, TVDB_API_KEY, TVDB_USER_KEY and TVDB_USER_NAME
    if [[ -z "${_SEARCH_TEXT:-}" ]]; then
        echo 'No search text!'
        usage
    fi
    if [[ -z "${TVDB_API_KEY:-}" ]]; then
        echo 'API key is not set!'
        echo '  ~$ export TVDB_API_KEY="<apikey>"'
        usage
    fi
    if [[ -z "${TVDB_USER_KEY:-}" ]]; then
        echo 'User key is not set!'
        echo '  ~$ export TVDB_USER_KEY="<userkey>"'
        usage
    fi
    if [[ -z "${TVDB_USER_NAME:-}" ]]; then
        echo 'User name is not set!'
        echo '  ~$ export TVDB_USER_NAME="<username>"'
        usage
    fi
}

get_token_from_result() {
    # Return token from $1 data
    if [[ "$1" == *"{\"token"* ]]; then
        echo "$1" | $_JQ -r .token | tee "$_TOKEN_FILE"
    else
        echo "$1" >&2 && exit 1
    fi
}

get_series_id_from_result() {
    # Return series id from $1 data
    if [[ "$1" == *"{\"data"* ]]; then
        echo "$1" | tee "$_TMP_FILE_SERIES" | $_JQ -r '.data | .[].id'
    else
        echo "$1" >&2 && exit 1
    fi
}

get_episodes_from_response() {
    # Return data from $1 response
    # $2: tmp file
    if [[ "$1" == *"\"data\""* ]]; then
        if [[ -s "$2" ]]; then
            currentEpisodes=$($_JQ -r '.' < "$2")
            newEpisodes=$(echo "$1" | $_JQ -r '.data')
            echo "${currentEpisodes}${newEpisodes}" | sed -E 's/\]\[/,/' > "$2"
        else
            echo "$1" | $_JQ -r '.data' > "$2"
        fi
    else
        echo "$1" >&2
    fi
}

get_max_page_from_response() {
    # Return max page of responses
    if [[ "$1" == *"\"links\""* ]]; then
        echo "$1" | $_JQ -r '.links.last'
    else
        echo "$1" >&2
    fi
}

get_series_id() {
    # Call series search API to get series id(s)
    result=$($_CURL -sSX GET \
        --header 'Accept: application/json' \
        --header 'Authorization: Bearer '"$_TOKEN" "$_API_SEARCH_SERIES?name=$_SEARCH_TEXT")

    get_series_id_from_result "$result"
}

get_episodes() {
    # Call episodes API to get episodes data
    # $1: series id
    url=$(echo $_API_SERIES_EPISODES | sed -E 's/\{id\}/'"$id"'/')
    result=$($_CURL -sSX GET \
        --header 'Accept: application/json' \
        --header 'Authorization: Bearer '"$_TOKEN" "$url")

    maxpage=$(get_max_page_from_response "$result")
    for (( i = 0; i < maxpage; i++ )); do
        result=$($_CURL -sSX GET \
            --header 'Accept: application/json' \
            --header 'Authorization: Bearer '"$_TOKEN" "$url?page=$((i+1))")
        get_episodes_from_response "$result" "$_TMP_FILE_EPISODES"
    done
}

get_series_status() {
    # Return series status from $2 data: Ended, Continuing...
    # $1: series id
    # $2: data file
    $_JQ -r '.data | .[] | select(.id==($id | tonumber)) | .status' --arg id "$1" < "$2"
}

get_series_firstaired_year() {
    # Return year of a series first aired
    # $1: series id
    # $2: data file
    local date
    date=$($_JQ -r '.data | .[] | select(.id==($id | tonumber)) | .firstAired' --arg id "$1" < "$2")
    if [[ -z "$date" ]]; then
        echo "0"
    else
        date -d"$date" +%Y
    fi
}

get_imdb_id_from_file() {
    # Return imdb id from $1
    $_JQ -r '.[] | select(.airedSeason!=0 and .firstAired>=$date) | .imdbId' --arg date "$(get_search_date)"< "$1"
}

get_imdb_rating() {
    # Get IMDb rating and inject imdbRating field into $1
    # $1: episodes data
    local rating
    sed -i 's/imdbId.*,/& "imdbRating": "",/' "$1"
    for id in $(get_imdb_id_from_file "$1"); do
        rating=$($_CURL -sS "$_IMDB_URL/$id/" | grep 'itemprop=\"ratingValue' | sed -E 's/.*ratingValue\">//;s/<\/span.*//')
        if [[ "$rating" ]]; then
            sed -i "s/imdbId\": \"$id\", \"imdbRating\": \"\"/imdbId\": \"$id\", \"imdbRating\": \"$rating\"/" "$1"
        fi
    done
}

get_search_date() {
    # Return search date accordingly
    local date
    date="0000-00-00"
    [[ "${_FUTURE_AIRED:-}" == true ]] && date=$(date +"%Y-%m-%d")
    [[ "${_DATE_AIRED:-}" ]] && date="$_DATE_AIRED"
    echo "$date"
}

fetch_token() {
    # Fetch token from tvdb API
    if [[ ! -f "$_TOKEN_FILE" ]]; then
        _TOKEN=$(login)
    else
        time_yesterday=$(date --date="yesterday" +%s)
        time_file_modified=$(date +%s -r "$_TOKEN_FILE")
        _TOKEN=$(cat "$_TOKEN_FILE")
        if [[ "$time_yesterday" -ge "$time_file_modified" ]]; then
            _TOKEN=$(refresh_token) || true
            if [[ "$_TOKEN" == "" ]]; then
                _TOKEN=$(login)
            fi
        fi
    fi
}

login() {
    # Call login API and save token
    result=$($_CURL -sSX POST \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json' \
        --header 'Authorization: Bearer '"$TVDB_API_KEY" \
        -d '{
            "apikey": "'"$TVDB_API_KEY"'",
            "userkey": "'"$TVDB_USER_KEY"'",
            "username": "'"$TVDB_USER_NAME"'"
        }' "$_API_LOGIN")

    get_token_from_result "$result"
}

refresh_token() {
    # Call refresh token API
    result=$($_CURL -sSX GET \
        --header 'Accept: application/json' \
        --header 'Authorization: Bearer '"$_TOKEN" "$_API_REFRESH_TOKEN")

    get_token_from_result "$result"
}

print_series_info() {
    # Print out series info
    # $1: series id
    # $2: data file
    printf "%b\n" "$($_JQ -r '.data | .[] | select(.id==($id | tonumber)) | "\\033[1m\\e[33m" + .seriesName + "\\e[0m", "\\033[1mFirst Aired:\\033[0m+" + .firstAired, "\\033[1mStatus:\\033[0m+" + .status, "\\033[1mOverview:\\033[0m+" + .overview, "+"' --arg id "$1" < "$2" | column -t -s"+")"
}

print_episodes_info() {
    # Print out series info
    # $1: episodes file
    if [[ "${_SHOW_RATING:-}" ]]; then
        get_imdb_rating "$_TMP_FILE_EPISODES"
        printf "%b\n" "$($_JQ -r -s '.[] | sort_by(.firstAired) | .[] | select(.airedSeason!=0 and .firstAired>=$date) | "\(.firstAired)+S\(.airedSeason)E\(.airedEpisodeNumber)+\\e[32m\(.episodeName)\\e[0m+\\e[33m\(.imdbRating)\\e[0m"' --arg date "$(get_search_date)"< "$1" | column -t -s "+")"
    else
        printf "%b\n" "$($_JQ -r -s '.[] | sort_by(.firstAired) | .[] | select(.airedSeason!=0 and .firstAired>=$date) | "\(.firstAired)+S\(.airedSeason)E\(.airedEpisodeNumber)+\\e[32m\(.episodeName)\\e[0m"' --arg date "$(get_search_date)"< "$1" | column -t -s"+")"
    fi
}

search_tv_series() {
    # Show serach results
    for id in $(get_series_id);do
        true > $_TMP_FILE_EPISODES
        togglePrint=true

        if [[ "${_YEAR_RANGE_FIRSTAIRED:-}" ]]; then
            year=$(get_series_firstaired_year "$id" "$_TMP_FILE_SERIES")
            if [[  "$year" -lt "$_MIN_YEAR_FIRSTAIRED" || "$year" -gt "$_MAX_YEAR_FIRSTAIRED" ]]; then
                togglePrint=false
            fi
        fi

        if [[ "${_CONTINUING_AIRED:-}" == true ]]; then
            if [[ $(get_series_status "$id" "$_TMP_FILE_SERIES") != "Continuing" ]]; then
                togglePrint=false
            fi
        fi

        if [[ "$togglePrint" == true ]]; then
            echo ""
            print_series_info "$id" "$_TMP_FILE_SERIES"
            if [[ -z "${_SHOW_SERIES_ONLY:-}" ]]; then
                get_episodes "$id" && print_episodes_info "$_TMP_FILE_EPISODES"
            fi
        fi
    done
}

main() {
    set_var "$@"
    check_var
    set_api
    fetch_token
    search_tv_series
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

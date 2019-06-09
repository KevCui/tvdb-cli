#!/usr/bin/env bash
#
# Fetch TV series infomation from tvdb
#
#/ Usage:
#/   ./tvdb.sh <search_text>
#/
#/ Options:
#/   --help:     Display this help message

usage() {
    # Display usage message
    grep '^#/' "$0" | cut -c4-
    exit 0
}

set_var() {
    # Declare variables used in script
    expr "$*" : ".*--help" > /dev/null && usage

    _SEARCH_TEXT=$( echo "$@" | sed -E 's/ /%20/g')
    _HOST="https://api.thetvdb.com"
    _TOKEN_FILE="./.token"
    _TMP_FILE_SERIES="./.tmp.series"
    _TMP_FILE_EPISODES="./.tmp.episodes"
    _TOKEN=""
    _CURL=$(command -v curl)
    _JQ=$(command -v jq)
    check_command "curl" "$_CURL"
    check_command "jq" "$_JQ"

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

check_command() {
    # Check command if it exists
    if [[ ! "$2" ]]; then
        echo "Command \"$1\" not found!"
        exit 1
    fi
}

check_var() {
    # Check _SEARCH_TEXT, TVDB_API_KEY, TVDB_USER_KEY and TVDB_USER_NAME
    if [[ -z "$_SEARCH_TEXT" ]]; then
        echo 'No search text!'
        usage && exit 1
    fi
    if [[ -z "$TVDB_API_KEY" ]]; then
        echo 'API key is not set!'
        echo '  ~$ export TVDB_API_KEY="<apikey>"'
        usage && exit 1
    fi
    if [[ -z "$TVDB_USER_KEY" ]]; then
        echo 'User key is not set!'
        echo '  ~$ export TVDB_USER_KEY="<userkey>"'
        usage && exit 1
    fi
    if [[ -z "$TVDB_USER_NAME" ]]; then
        echo 'User name is not set!'
        echo '  ~$ export TVDB_USER_NAME="<username>"'
        usage && exit 1
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

fetch_token() {
    # Fetch token from tvdb API
    if [[ ! -f "$_TOKEN_FILE" ]]; then
        _TOKEN=$(login)
    else
        time_yesterday=$(date --date="yesterday" +%s)
        time_file_modified=$(date +%s -r "$_TOKEN_FILE")
        _TOKEN=$(cat "$_TOKEN_FILE")
        if [[ "$time_yesterday" -ge "$time_file_modified" ]]; then
            _TOKEN=$(refresh_token)
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

search_tv_series() {
    # Show serach results
    for id in $(get_series_id);do
        true > $_TMP_FILE_EPISODES
        echo ""
        $_JQ -r '.data | .[] | select(.id==($id | tonumber)) | .seriesName, "First Aired: " + .firstAired, "Status: " + .status, "Overview: " + .overview' --arg id "$id" < "$_TMP_FILE_SERIES"
        get_episodes "$id"
        $_JQ -r -s '.[] | sort_by(.firstAired) | .[] | select(.airedSeason!=0) | "\(.firstAired)\tS\(.airedSeason)E\(.airedEpisodeNumber)\t\(.episodeName)"' < "$_TMP_FILE_EPISODES"
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

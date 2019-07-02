#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/tvdb.bats
#

BATS_TEST_SKIPPED=

clean_up_files() {
    rm -rf "$_TOKEN_FILE"
    rm -rf "$_TMP_FILE_SERIES"
    rm -rf "$_TMP_FILE_EPISODES"
}

setup() {
    _SCRIPT="./tvdb.sh"
    _SEARCH_TEXT="toto"
    TVDB_API_KEY="key"
    TVDB_USER_KEY="tata"
    TVDB_USER_NAME="jack"

    _JQ=$(command -v jq)
    _CURL=$(command -v curl)

    _TEST_DIR="./test"
    _TOKEN_FILE="$_TEST_DIR/test.token"
    _TMP_FILE_SERIES="$_TEST_DIR/test.series"
    _TMP_FILE_EPISODES="$_TEST_DIR/test.episodes"

    source $_SCRIPT
    clean_up_files
}

teardown() {
    clean_up_files
}

@test "CHECK: set_var(): --help" {
    run set_var --help
    [ "$status" -eq 0 ]
    [ "$output" = "$(usage)" ]
}

@test "CHECK: set_var(): -h" {
    run set_var -h
    [ "$status" -eq 0 ]
    [ "$output" = "$(usage)" ]
}

@test "CHECK: check_command(): command found" {
    run check_command "bats" $(command -v bats)
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_command(): command not found" {
    run check_command "notacommand" $(command -v itisnotacommand)
    [ "$status" -eq 1 ]
    [ "$output" = "Command \"notacommand\" not found!" ]
}

@test "CHECK: check_var(): all mandatory variables are set" {
    run check_var
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_var(): no \$_SEARCH_TEXT" {
    unset _SEARCH_TEXT
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "No search text!" ]
}

@test "CHECK: check_var(): no \$TVDB_API_KEY" {
    unset TVDB_API_KEY
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "API key is not set!" ]
}

@test "CHECK: check_var(): no \$TVDB_USER_KEY" {
    unset TVDB_USER_KEY
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "User key is not set!" ]
}

@test "CHECK: check_var(): no \$TVDB_USER_NAME" {
    unset TVDB_USER_NAME
    run check_var
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "User name is not set!" ]
}

@test "CHECK: check_firstaired_year_range(): min < max" {
    min="2018"
    max="2019"
    run check_firstaired_year_range "$min" "$max"
    [ "$status" -eq 0 ]
}

@test "CHECK: check_firstaired_year_range(): min == max" {
    min="2019"
    max="2019"
    run check_firstaired_year_range "$min" "$max"
    [ "$status" -eq 0 ]
}

@test "CHECK: check_firstaired_year_range(): min > max" {
    min="2020"
    max="2019"
    run check_firstaired_year_range "$min" "$max"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Invalid year range: -y <year_range>!" ]
}

@test "CHECK: get_token_from_result(): correct token" {
    token="hereistoken"
    response='{"token": "'$token'"}'
    run get_token_from_result "$response"
    [ "$status" -eq 0 ]
    [ "$output" = "$token" ]
    tokenFromFile=$(cat "$_TOKEN_FILE")
    [ "$tokenFromFile" = "$token" ]
}

@test "CHECK: get_token_from_result(): no token" {
    response='{"noken": "hereistoken"}'
    run get_token_from_result "$response"
    [ "$status" -eq 1 ]
    [ "$output" = "$response" ]
    run cat "$_TOKEN_FILE"
    [ "$status" -eq 1 ]
}

@test "CHECK: get_series_id_from_result(): correct series id" {
    data=$(cat "$_TEST_DIR/series.testdata.json")
    run get_series_id_from_result "$data"
    [ "$status" -eq 0 ]
    [ "$output" = "9999" ]
    dataFromFile=$(cat "$_TMP_FILE_SERIES")
    [ "$dataFromFile" = "$data" ]
}

@test "CHECK: get_series_id_from_result(): multiple series" {
    data=$(cat "$_TEST_DIR/multiple.series.testdata.json")
    run get_series_id_from_result "$data"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "121361" ]
    [ "${lines[1]}" = "311939" ]
    [ "${lines[2]}" = "321282" ]
    dataFromFile=$(cat "$_TMP_FILE_SERIES")
    [ "$dataFromFile" = "$data" ]
}

@test "CHECK: get_series_id_from_result(): no series data" {
    data="nodata"
    run get_series_id_from_result "$data"
    [ "$status" -eq 1 ]
    [ "$output" = "$data" ]
    run cat "_TMP_FILE_SERIES"
    [ "$status" -eq 1 ]
}

@test "CHECK: get_episodes_from_response(): correct episodes data" {
    data=$(cat "$_TEST_DIR/episodes.all.testdata.json")
    dataFromRef=$(cat "$_TEST_DIR/episodes.all.reference.json")
    run get_episodes_from_response "$data" "$_TMP_FILE_EPISODES"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    dataFromFile=$(cat "$_TMP_FILE_EPISODES")
    [ "$dataFromFile" = "$dataFromRef" ]
}

@test "CHECK: get_episodes_from_response(): correct episodes data - 2 parts" {
    part1Data=$(cat "$_TEST_DIR/episodes.part1.testdata.json")
    part2Data=$(cat "$_TEST_DIR/episodes.part2.testdata.json")
    dataFromRef=$(cat "$_TEST_DIR/episodes.merge.reference.json")

    run get_episodes_from_response "$part1Data" "$_TMP_FILE_EPISODES"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    run get_episodes_from_response "$part2Data" "$_TMP_FILE_EPISODES"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]

    dataFromFile=$(cat "$_TMP_FILE_EPISODES")
    [ "$dataFromFile" = "$dataFromRef" ]
}

@test "CHECK: get_max_page_from_response(): correct data" {
    data=$(cat "$_TEST_DIR/link.testdata.json")
    run get_max_page_from_response "$data"
    [ "$status" -eq 0 ]
    [ "$output" = "999" ]
}

@test "CHECK: get_max_page_from_response(): no data" {
    data="nodata"
    run get_max_page_from_response "$data"
    [ "$status" -eq 0 ]
    [ "$output" = "$data" ]
}

@test "CHECK: get_series_status()" {
    run get_series_status "121361" "$_TEST_DIR/multiple.series.testdata.json"
    [ "$status" -eq 0 ]
    [ "$output" = "Continuing" ]
}

@test "CHECK: get_series_firstaired_year(): correct date" {
    run get_series_firstaired_year "121361" "$_TEST_DIR/multiple.series.testdata.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2011" ]
}

@test "CHECK: get_series_firstaired_year(): no date" {
    run get_series_firstaired_year "321282" "$_TEST_DIR/multiple.series.testdata.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "CHECK: get_search_data(): default date" {
    run get_search_date
    [ "$status" -eq 0 ]
    [ "$output" = "0000-00-00" ]
}

@test "CHECK: get_search_data(): today" {
    today=$(date +"%Y-%m-%d")
    _FUTURE_AIRED=true
    run get_search_date
    [ "$status" -eq 0 ]
    [ "$output" = "$today" ]
}

@test "CHECK: get_search_data(): aired data" {
    _DATE_AIRED="1020-02-20"
    run get_search_date
    [ "$status" -eq 0 ]
    [ "$output" = "$_DATE_AIRED" ]
}

@test "CHECK: get_search_data(): today && aired data" {
    today=$(date +"%Y-%m-%d")
    _DATE_AIRED="1020-02-20"
    _FUTURE_AIRED=true
    run get_search_date
    [ "$status" -eq 0 ]
    [ "$output" = "$_DATE_AIRED" ]
}

@test "CHECK: get_imdb_id_from_file()" {
    _DATE_AIRED="2019-05-27"
    run get_imdb_id_from_file "$_TEST_DIR/episodes.merge.reference.json"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "tt9166678" ]
    [ "${lines[1]}" = "tt9166696" ]
}

@test "CHECK: print_series_info()" {
    data=$(cat "$_TEST_DIR/series.info.reference.text")
    run print_series_info "321282" "$_TEST_DIR/multiple.series.testdata.json"
    [ "$status" -eq 0 ]
    [ "$output" = "$data" ]
}

@test "CHECK: print_episodes_info(): with rating" {
    get_imdb_rating() {
        echo "" > /dev/null
    }
    _DATE_AIRED="2019-05-05"
    _SHOW_RATING=true
    data=$(cat "$_TEST_DIR/episodes.rating.reference.text")
    run print_episodes_info "$_TEST_DIR/episodes.rating.testdata.json"
    [ "$status" -eq 0 ]
    [ "$output" = "$data" ]
}

@test "CHECK: print_episodes_info(): without rating" {
    _DATE_AIRED="2019-05-13"
    data=$(cat "$_TEST_DIR/episodes.info.reference.text")
    run print_episodes_info "$_TEST_DIR/episodes.merge.reference.json"
    [ "$status" -eq 0 ]
    [ "$output" = "$data" ]
}

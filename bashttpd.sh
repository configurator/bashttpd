#!/bin/bash

# Input env variables
# ROOT: root path to serve (default .)
# PORT: port number to listen on (default 8080)
# VERBOSE: if nonempty, all network i/o will be logged (default "")

set -e
set -u
set -o posix
set -o pipefail

PORT="${PORT:-8080}"
ROOT="$(realpath ${ROOT:-.})"

fifo="$(mktemp -u)"
mkfifo "$fifo"

CRLF="\r\n"
export IFS=''

function log() {
    printf "[$(date "+%Y-%m-%d %H:%M:%S")] $*\r\n" >&2
}
    
function logverbose() {
    if [ -n "${VERBOSE:-}" ]; then
        log "$@"
    fi
}

function out() {
    printf "$*"
    printf "$CRLF"
    logverbose "> $*"
}

function urldecode() {
    local value="$1"
    value="${value//+/ }" # Decode + as space
    value="${value//%/\\x}" # Convert %00 to \x00
    printf "$value" # Printf decodes escape strings like \x00 etc
}

function isInRootDir() {
    local path="$1"
    path="$(realpath "$path")"
    [[ "$path" == "$ROOT"/* ]] # Return result of condition
}

function httpError() {
    out "HTTP/1.1 $1"
    out "Connection: Close"
    out
}

function serveFile() {
    local fullPath="$ROOT/$1"
    local includeBody="$2"
    if [ -d "$fullPath" ]; then
        fullPath="$fullPath/index.html"
    fi

    if isInRootDir "$fullPath" && [ -f "$fullPath" ]; then
        out "HTTP/1.1 200 OK"
        out "Content-Length: $(stat -c %s "$fullPath")"
        out "Connection: Close"
        out
        if "$includeBody"; then
            cat "$fullPath"
        fi
    else
        httpError "404 File not found"
    fi
}

function cleanRequest() {
    while true; do
        read line || break
        echo "$line" | tr -d '\r'
    done
}

function handleRequest() {
    # Parse the first line
    local firstLine
    read firstLine
    logverbose "< $firstLine"
    local protocol="${firstLine##* }"
    local method="${firstLine%% *}"
    firstLine="${firstLine% *}"
    local path="${firstLine#* }"
    local includeBody

    if [[ "$protocol" != "HTTP/1.1" ]]; then
        log "505 HTTP Version Not Supported: $protocol"
        httpError "505 HTTP Version Not Supported"
        return
    fi

    case "$method" in
        GET)
            includeBody=true
            ;;
        HEAD)
            includeBody=false
            ;;
        *)
            httpError "501 Not implemented"
            return
            ;;
    esac

    # Read headers
    local -A headers
    while true; do
        local headerLine
        read headerLine
        logverbose "< $headerLine"
        if [[ "$headerLine" == "" ]]; then
            break
        fi

        local name="${headerLine%%:*}"
        local value="${headerLine#*:}"
        headers["$name"]="${value# }"
    done

    # Handle request
    log "$method ${headers[Host]}$path"
    serveFile "$path" "$includeBody"
}

cleanAndHandleRequest() {
    exec 1> "$fifo"
    cleanRequest | handleRequest
    exec 1>&-
}

while true; do
    <"$fifo" nc -q 0 -l -p "$PORT" | cleanAndHandleRequest
done

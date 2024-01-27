#!/bin/bash

LOG_FILE=""

LOG_HISTORY_FILE="log_history.txt"
KEYWORDS_FILE="keywords.txt"

# Loading log file history
if [[ -f "$LOG_HISTORY_FILE" ]]; then
    mapfile -t LOG_HISTORY < "$LOG_HISTORY_FILE"
    LOG_FILE=${LOG_HISTORY[-1]} # Last log file in history
else
    LOG_HISTORY=()
    LOG_FILE=""
fi

# Loading keywords
if [[ -f "$KEYWORDS_FILE" ]]; then
    mapfile -t KEYWORDS < "$KEYWORDS_FILE"
else
    KEYWORDS=()
fi

INTRUDERS_IPS=()  # Array for storing found IP addresses

show_help() {
    echo "Commands:"
    echo "  intruders (i) - Prints IP addresses containing at least one keyword"
    echo "  successful-attacks (sa) - Searches for successful POST requests with code 200 from 'intruders' IP addresses"
    echo "  search (s) <index> - Searches for an IP address based on its index in the intruders list"
    echo "  list (l) - Displays unique IP addresses"
    echo "  add-log (al) <log_file> - Changes the currently used log file"
    echo "  show-logs (sl) - Displays the history of used log files"
    echo "  switch-log (sw) <index> - Switches to a log file based on the index in history"
    echo "  add-keyword (ak) <keyword> - Adds a keyword to the search list"
    echo "  remove-keyword (rk) <keyword> - Removes a keyword from the list"
    echo "  show-keywords (sk) - Displays the list of keywords for searching"
    echo "  quit (q) - Exits the script"
    echo "  help (h) - Displays this help message"
}

search_logs() {
    local keyword=$1
    local base_log=$2

    # Searching the current log
    grep "$keyword" "$base_log"

    # Creating a pattern for rotated logs
    local log_pattern="${base_log}.*"

    # Searching rotated logs
    for log in $log_pattern; do
        if [[ "$log" =~ \.gz$ ]]; then
            # For gzip compressed logs
            zgrep "$keyword" "$log"
        else
            # For uncompressed logs
            grep "$keyword" "$log"
        fi
    done
}

while true; do
    read -e -p "shell>" cmd args

    case "$cmd" in
        s|search)
            if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#INTRUDERS_IPS[@]} ]; then
                ip_address="${INTRUDERS_IPS[$args]}"
                search_logs "$ip_address" "$LOG_FILE" | less -S
            else
                echo "Invalid index: $args"
            fi
            ;;
        l|list)
            cut -d' ' -f1 "$LOG_FILE" | sort -u
            ;;
        al|add-log)
            if [[ -f "$args" ]]; then
                LOG_FILE="$args"

                # Removing old record if exists
                for i in "${!LOG_HISTORY[@]}"; do
                    if [[ "${LOG_HISTORY[$i]}" == "$LOG_FILE" ]]; then
                        unset 'LOG_HISTORY[$i]'
                    fi
                done

                LOG_HISTORY+=("$LOG_FILE") # Adding to the end of history
                printf "%s\n" "${LOG_HISTORY[@]}" > "$LOG_HISTORY_FILE" # Updating history file
                echo "Log file changed to: $LOG_FILE"
            else
                echo "Log file '$args' not found."
            fi
            ;;
        sl|show-logs)
            echo "Log file history:"
            for i in "${!LOG_HISTORY[@]}"; do
                echo "$i: ${LOG_HISTORY[$i]}"
            done
            ;;
        sw|switch-log)
            if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#LOG_HISTORY[@]} ]; then
                LOG_FILE="${LOG_HISTORY[$args]}"
                
                # Updating history - removing and adding to the end
                unset 'LOG_HISTORY[$args]'
                LOG_HISTORY=("${LOG_HISTORY[@]}" "$LOG_FILE")

                # Saving the updated history to the file
                printf "%s\n" "${LOG_HISTORY[@]}" > "$LOG_HISTORY_FILE"
                
                echo "Switched to log file: $LOG_FILE"
            else
                echo "Invalid index: $args"
            fi
            ;;
        ak|add-keyword)
            KEYWORDS+=("$args")
            echo "$args" >> "$KEYWORDS_FILE"
            echo "Keyword '$args' added."
            ;;
        rk|remove-keyword)
            if [[ " ${KEYWORDS[*]} " =~ " $args " ]]; then
                # Removing the keyword
                KEYWORDS=("${KEYWORDS[@]/$args}")
                KEYWORDS=(${KEYWORDS[@]})  # Removing empty elements
                # Removing empty lines and updating the keyword file
                printf "%s\n" "${KEYWORDS[@]}" | grep . > "$KEYWORDS_FILE"

                echo "Keyword '$args' removed."
            else
                echo "Keyword '$args' not found."
            fi
            ;;
        sk|show-keywords)
            echo "List of keywords for searching:"
            for kw in "${KEYWORDS[@]}"; do
                echo "  - $kw"
            done
            ;;
        i|intruders)
            if [[ -f "$LOG_FILE" ]]; then
                if [ ${#KEYWORDS[@]} -eq 0 ]; then
                    echo "No keywords provided."
                else
                    INTRUDERS_IPS=($(for kw in "${KEYWORDS[@]}"; do
                        search_logs "$kw" "$LOG_FILE" | cut -d' ' -f1
                    done | sort -u))

                    echo "Found IP addresses:"
                    for i in "${!INTRUDERS_IPS[@]}"; do
                        echo "$i: ${INTRUDERS_IPS[$i]}"
                    done
                fi
            else
                echo "Log file is not set. Use 'change-log' to set it."
            fi
            ;;
        sa|successful-attacks)
            if [[ -f "$LOG_FILE" ]]; then
                if [ ${#KEYWORDS[@]} -eq 0 ]; then
                    echo "No keywords provided."
                else
                    INTRUDERS_IPS=($(for kw in "${KEYWORDS[@]}"; do
                        search_logs "$kw" "$LOG_FILE" | cut -d' ' -f1
                    done | sort -u))

                    for ip in "${INTRUDERS_IPS[@]}"; do
                        search_logs "$ip" "$LOG_FILE" | grep "POST" | grep " 200 "
                    done | less -S
                fi
            else
                echo "Log file is not set. Use 'al, add-log' to set it."
            fi
            ;;
        q|quit)
            break
            ;;
        h|help)
            show_help
            ;;
        *)
            echo "Unknown command: $cmd"
            show_help
            ;;
    esac
done

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
    echo "  search (s) <index> - Searches for an IP address based on its index in the intruders list and displays the log entries"
    echo "  export (e) <index> - Exports log entries for the given IP address index to a file"
    echo "  export-all (ea) - Exports log entries for all IP addresses in the intruders list to separate files"
    echo "  list (l) - Displays unique IP addresses"
    echo "  add-log (al) <log_file> - Adds a new log file"
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

    # Check if the base log file exists
    if [[ -f "$base_log" ]]; then
        grep "$keyword" "$base_log"
    fi

    # Create a pattern for rotated logs
    local log_pattern="${base_log}.*"

    # Search through rotated logs
    for log in $log_pattern; do
        if [[ -f "$log" ]]; then
            if [[ "$log" =~ \.gz$ ]]; then
                # For gzip compressed logs
                zgrep "$keyword" "$log"
            else
                # For uncompressed logs
                grep "$keyword" "$log"
            fi
        fi
    done
}


while true; do
    read -e -p "shell>" cmd args

    case "$cmd" in
        s|search)
            if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#INTRUDERS_INFO[@]} ]; then
                selected_entry="${INTRUDERS_INFO[$args]}"
                echo "Searching logs for: $selected_entry"
	        # Split the entry into date and IP address
                IFS=' ' read -r entry_date entry_ip <<< "$selected_entry"

	        # Use search_logs function to find logs with the IP address
                search_logs "$entry_ip" "$LOG_FILE" | less -S
            else
                echo "Invalid index: $args"
            fi
            ;;

	e|export)
	    if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#INTRUDERS_INFO[@]} ]; then
	        selected_entry="${INTRUDERS_INFO[$args]}"
	        echo "Exporting logs for: $selected_entry"
	        # Split the entry into date and IP address
	        IFS=' ' read -r entry_date entry_ip <<< "$selected_entry"

	        # Create a directory based on the base name of the log file
	        log_dir=$(basename "$LOG_FILE")
	        mkdir -p "${log_dir}/${entry_date}"
	        # Create a file name with date and IP address
	        filename="${log_dir}/${entry_date}/${entry_ip}.log"
	
	        # Use search_logs function to find logs with the IP address and write to file
	        search_logs "$entry_ip" "$LOG_FILE" > "$filename"
	
	        echo "Logs exported to $filename"
	    else
	        echo "Invalid index: $args"
	    fi
	    ;;

	ea|export-all)
	    if [ ${#INTRUDERS_INFO[@]} -eq 0 ]; then
	        echo "No intruders data to export."
	        return
	    fi
	
	    # Create a directory based on the base name of the log file
	    log_dir=$(basename "$LOG_FILE")
	    mkdir -p "$log_dir"
	
	    for entry in "${INTRUDERS_INFO[@]}"; do
	        echo "Exporting logs for: $entry"
	        # Split the entry into date and IP address
	        IFS=' ' read -r entry_date entry_ip <<< "$entry"

	        mkdir -p "${log_dir}/${entry_date}"

	        # Create a file name with date and IP address
	        filename="${log_dir}/${entry_date}/${entry_ip}.log"
	
	        # Use search_logs function to find logs with the IP address and write to file
	        search_logs "$entry_ip" "$LOG_FILE" > "$filename"
	
	        echo "Logs exported to $filename"
	    done
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
    	        INTRUDERS_INFO=()
        	    for kw in "${KEYWORDS[@]}"; do
	                while IFS= read -r line; do
    	                if [[ "$line" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ -\ -\ \[([0-9]{2})/([A-Za-z]{3})/([0-9]{4}) ]]; then
        	                ip="${BASH_REMATCH[1]}"
                	        day="${BASH_REMATCH[2]}"
	                        month="${BASH_REMATCH[3]}"
    	                        year="${BASH_REMATCH[4]}"
        	                # Convert the date to a sortable format (YYYY-MM-DD)
                	        # This requires a mapping from month names to numbers
	                        month_num=$(date -d "01 $month 2000" +%m)
                                sortable_date="$year-$month_num-$day"
        	                INTRUDERS_INFO+=("$sortable_date $ip")
                	    fi
	                done < <(search_logs "$kw" "$LOG_FILE")
    	        done

        	    # Sort the array by date and display the results
	            IFS=$'\n' INTRUDERS_INFO=($(sort -u <<<"${INTRUDERS_INFO[*]}"))
	            unset IFS

    		    echo "Found date IP entries sorted by date:"
	            for i in "${!INTRUDERS_INFO[@]}"; do
	                printf "%3d: %s\n" "$i" "${INTRUDERS_INFO[$i]}"
	            done
	        fi
	    else
	        echo "Log file is not set. Use 'al, add-log' to set it."
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

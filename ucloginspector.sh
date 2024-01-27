#!/bin/bash

LOG_FILE=""


LOG_HISTORY_FILE="log_history.txt"
KEYWORDS_FILE="keywords.txt"



# Načtení historie log souborů
if [[ -f "$LOG_HISTORY_FILE" ]]; then
    mapfile -t LOG_HISTORY < "$LOG_HISTORY_FILE"
    LOG_FILE=${LOG_HISTORY[-1]} # Poslední log soubor v historii
else
    LOG_HISTORY=()
    LOG_FILE=""
fi

# Načtení klíčových slov
if [[ -f "$KEYWORDS_FILE" ]]; then
    mapfile -t KEYWORDS < "$KEYWORDS_FILE"
else
    KEYWORDS=()
fi


INTRUDERS_IPS=()  # Pole pro uchování nalezených IP adres

show_help() {
    echo "Příkazy:"
    echo "  intruders - Vypíše IP adresy obsahující alespoň jedno klíčové slovo"
    echo "  successful-attacks - Vyhledá úspěšné POST dotazy s kódem 200 od IP adres 'intruders'"
    echo "  search <keyword> - Hledá klíčové slovo v logu"
    echo "  list - Zobrazí unikátní IP adresy"
    echo "  add-log <log_file> - Změní aktuálně používaný log soubor"
    echo "  show-logs - Zobrazí historii použitých log souborů"
    echo "  switch-log <index> - Přepne na log soubor podle indexu v historii"
    echo "  add-keyword <keyword> - Přidá klíčové slovo do seznamu pro vyhledávání"
    echo "  remove-keyword <keyword> - Odebere klíčové slovo ze seznamu"
    echo "  show-keywords - Zobrazí seznam klíčových slov pro vyhledávání"
    echo "  quit - Ukončí skript"
    echo "  help - Zobrazí tuto nápovědu"
}


search_logs() {
    local keyword=$1
    local base_log=$2

    # Prohledávání aktuálního logu
    grep "$keyword" "$base_log"

    # Vytvoření vzoru pro odrotované logy
    local log_pattern="${base_log}.*"

    # Prohledávání odrotovaných logů
    for log in $log_pattern; do
        if [[ "$log" =~ \.gz$ ]]; then
            # Pro gzip komprimované logy
            zgrep "$keyword" "$log"
        else
            # Pro nekomprimované logy
            grep "$keyword" "$log"
        fi
    done
}







while true; do
    read -e -p "shell>" cmd args

    case "$cmd" in

        search)
            if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#INTRUDERS_IPS[@]} ]; then
                ip_address="${INTRUDERS_IPS[$args]}"
                search_logs "$ip_address" "$LOG_FILE" | less -S
            else
                echo "Neplatný index: $args"
            fi
            ;;
        list)
            cut -d' ' -f1 "$LOG_FILE" | sort -u
            ;;
        add-log)
            if [[ -f "$args" ]]; then
                LOG_FILE="$args"

                # Odebrání starého záznamu, pokud existuje
                for i in "${!LOG_HISTORY[@]}"; do
                    if [[ "${LOG_HISTORY[$i]}" == "$LOG_FILE" ]]; then
                        unset 'LOG_HISTORY[$i]'
                    fi
                done

                LOG_HISTORY+=("$LOG_FILE") # Přidání na konec historie
                printf "%s\n" "${LOG_HISTORY[@]}" > "$LOG_HISTORY_FILE" # Aktualizace souboru historie
                echo "Log soubor změněn na: $LOG_FILE"
            else
                echo "Log soubor '$args' nebyl nalezen."
            fi
            ;;
        show-logs)
            echo "Historie log souborů:"
            for i in "${!LOG_HISTORY[@]}"; do
                echo "$i: ${LOG_HISTORY[$i]}"
            done
            ;;
        switch-log)
            if [[ $args =~ ^[0-9]+$ ]] && [ $args -ge 0 ] && [ $args -lt ${#LOG_HISTORY[@]} ]; then
                LOG_FILE="${LOG_HISTORY[$args]}"
                
                # Aktualizace historie - odebrání a přidání na konec
                unset 'LOG_HISTORY[$args]'
                LOG_HISTORY=("${LOG_HISTORY[@]}" "$LOG_FILE")

                # Uložení aktualizované historie do souboru
                printf "%s\n" "${LOG_HISTORY[@]}" > "$LOG_HISTORY_FILE"
                
                echo "Přepnuto na log soubor: $LOG_FILE"
            else
                echo "Neplatný index: $args"
            fi
            ;;
	add-keyword)
	    KEYWORDS+=("$args")
	    echo "$args" >> "$KEYWORDS_FILE"
	    echo "Klíčové slovo '$args' přidáno."
        ;;

       remove-keyword)
            if [[ " ${KEYWORDS[*]} " =~ " $args " ]]; then
                # Odstranění klíčového slova
                KEYWORDS=("${KEYWORDS[@]/$args}")
		KEYWORDS=(${KEYWORDS[@]})  # Odstranění prázdných prvků
                # Odstranění prázdných řádků a aktualizace souboru s klíčovými slovy
                printf "%s\n" "${KEYWORDS[@]}" | grep . > "$KEYWORDS_FILE"

                echo "Klíčové slovo '$args' odebráno."
            else
                echo "Klíčové slovo '$args' nebylo nalezeno."
            fi
            ;;
        show-keywords)
            echo "Seznam klíčových slov pro vyhledávání:"
            for kw in "${KEYWORDS[@]}"; do
                echo "  - $kw"
            done
            ;;

        intruders)
            if [[ -f "$LOG_FILE" ]]; then
                if [ ${#KEYWORDS[@]} -eq 0 ]; then
                    echo "Nebyla zadána žádná klíčová slova."
                else
                    INTRUDERS_IPS=($(for kw in "${KEYWORDS[@]}"; do
                        search_logs "$kw" "$LOG_FILE" | cut -d' ' -f1
                    done | sort -u))

                    echo "Nalezené IP adresy:"
                    for i in "${!INTRUDERS_IPS[@]}"; do
                        echo "$i: ${INTRUDERS_IPS[$i]}"
                    done
                fi
            else
                echo "Není nastaven log soubor. Použijte 'change-log' pro jeho nastavení."
            fi
            ;;
        successful-attacks)
            if [[ -f "$LOG_FILE" ]]; then
                if [ ${#KEYWORDS[@]} -eq 0 ]; then
                    echo "Nebyla zadána žádná klíčová slova."
                else
                    INTRUDERS_IPS=($(for kw in "${KEYWORDS[@]}"; do
                        search_logs "$kw" "$LOG_FILE" | cut -d' ' -f1
                    done | sort -u))

                    for ip in "${INTRUDERS_IPS[@]}"; do
                        search_logs "$ip" "$LOG_FILE" | grep "POST" | grep " 200 "
                    done | less -S
                fi
            else
                echo "Není nastaven log soubor. Použijte 'change-log' pro jeho nastavení."
            fi
            ;;
        quit)
            break
            ;;
        help)
            show_help
            ;;
        *)
            echo "Neznámý příkaz: $cmd"
            show_help
            ;;
    esac
done



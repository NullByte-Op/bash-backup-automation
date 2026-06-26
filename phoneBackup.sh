#!/bin/bash 




bootstrap(){

    # Terminal detection
    if [ -t 1 ];then
        IS_TERMINAL=true
    else
        IS_TERMINAL=false
    fi
    # Root perivilage detection
    if [ "$EUID" -eq 0 ];then
        LOG_DIR="/var/log/backups"
    else
        LOG_DIR="$HOME/.local/var/backups"
    fi

    LOG_FILE="$LOG_DIR/backup_script.log"
    LOCK_FILE="/tmp/phoneBackup.lock"
    CONFIG_DIR="$HOME/bin/scripts/backup_script/"
}


echo_terminal(){
    if $IS_TERMINAL;then
        echo "$1"
    fi
}

cleanup(){
    rm -f $LOCK_FILE
    echo_terminal "[*] Lock file removed."
}

lock_script(){
    
    if [ -f $LOCK_FILE ];then
        lock_pid=$(cat $LOCK_FILE)
        echo_terminal "Error: Script is already running under PID: $lock_pid"
        log "ERROR" "[-] Script is already running under PID: $lock_pid"
        trap - EXIT SIGINT SIGTERM 
        exit 1
    fi

    echo "$$" > $LOCK_FILE
}

setup_logging(){
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"

    if [ $? -ne 0 ];then
        echo "ERROR : Cannot create log directory at $LOG_DIR"
        exit 1
    fi
}

log(){
    local level=$1
    shift        # Remove first arg, in $@
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

rotate_logs_fallback(){

    local max_size=1048576
    local max_backups=3

    if [ ! -f "$LOG_FILE" ];then
        return 0
    fi

    local current_size=$(stat -c%s "$LOG_FILE")
    
    if [ "$current_size" -gt "$max_size" ];then
        echo_terminal "[*] Logrotate tool not found. Using fallback log rotation ..."

        # Remove old backup log
        rm -f "$LOG_FILE.$max_backups"


        # rotate old file
        for ((i=$((max_backups-1)); i>=1; i--));do
            if [ -f "$LOG_FILE.$i" ];then
                mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
            fi
        done

        # Change current file to number 1
        mv "$LOG_FILE" "$LOG_FILE.1"
        touch "$LOG_FILE"
        log "INFO" "Fallback log rotation completed."
    fi

}

manage_logs(){
    
    # PATH of log rotation config file
    local custom_logrotate_conf="$HOME/.local/var/backups/phone_backup.conf"

    # Check logrotate and config file
    if command -v logrotate >/dev/null 2>&1 &&  [ -f "$custom_logrotate_conf" ];then

        echo_terminal "[+] System logrotate detected and configured. System will handle logs."

        logrotate -s "$HOME/.local/var/backups/logrotate.status" "$custom_logrotate_conf"
    
    else
        # using our log rotate
        rotate_logs_fallback
    fi
}

banner(){    
    echo_terminal "*******************************"
    echo_terminal "This is a simple backup script."
    echo_terminal "*******************************"
}


get_backup(){
    
    general_title=$1
    title=$2
    src=$3
    dst=$4
    ip=$5
    username=$6
    port=$7

    echo_terminal "********************************"
    echo_terminal "[*] Starting Backup for $general_title [$title]"
    echo_terminal "[*] IP:PORT -> $ip:$port"
    echo_terminal "[*] User name -> $username"
    echo_terminal "[*] src-> $src"
    echo_terminal "[*] dst-> $dst"

    # Starting backup

    rsync -ar -e "ssh -p $port" ${username}@${ip}:${src} $dst


    if [ $? -eq 0 ]; then
        log "INFO" "Backup completed successfully for [$title]"
        return 0
    else
        log "ERROR" "Backup FAILED for $title"
        return 1
    fi

}


check_host(){
    
    local ip=$1
    local port=$2

    nc -w 5 -z $ip $port 2>/dev/null

    if [ $? != 0 ];then
        log "ERROR" "Connection refused to $ip:$port"
        exit 1
    else
        log "INFO" "$ip:$port connected."
        return 0
    fi

}

validate_yaml(){
    local config_file=$1

    # Read all config file 
    yq "." $config_file > /dev/null 2>&1

    if [ $? -ne 0 ];then
        log "ERROR" "Invalid YAML syntax in file : $config_file"
        return 1
    else
        return 0
    fi
}

process_configs(){
    
    local config_file=$1

    echo_terminal "[*] Proccessing [$config_file]"
    
    # Extract content in .yaml file
    general_title=$(yq '.title' $config_file )
    ip=$(yq -r '.ip' $config_file)
    username=$(yq -r '.username' $config_file)
    port=$(yq -r '.port' $config_file)
    
    # Extract directory name 
    titles=$(yq '.backups | keys []' $config_file)

    # Check IP and PORT
    check_host $ip $port

    for title in ${titles[@]};do
        src=$(yq -r ".backups.$title.src" $config_file)
        dst=$(yq -r ".backups.$title.dst" $config_file)

        get_backup $general_title $title $src $dst $ip $username $port
    done
}

read_config(){
    
    shopt -s nullglob
    local yaml_files=( /home/gameover/bin/scripts/backup_script/*.yaml )
    

    if [ ${#yaml_files[@]} -eq 0 ];then
        echo_terminal "[0] YAML file found."
        shopt -u nullglob
        exit 1
    else    
        echo_terminal "[*] Found ${#yaml_files[@]} file"
    fi

    for name in ${yaml_files[@]};do
        
        # Check yaml syntax is ok or not:
        if validate_yaml "$name"; then
            process_configs "$name"

        else
            echo_terminal "[!] Skipping corrupted file: $name"
        fi
    done

    shopt -u nullglob
}


main(){
    bootstrap
    banner

    trap cleanup EXIT SIGINT SIGTERM

    lock_script
    setup_logging
    manage_logs
    log "INFO" "Backup script started"

    read_config
    
    log "INFO" "Backup script finished"
    
}


main

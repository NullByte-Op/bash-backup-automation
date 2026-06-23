#!/bin/bash 



if [ -t 1 ];then
    IS_TERMINAL=true
else
    IS_TERMINAL=false
fi



LOG_DIR="/var/log/backups"

if [ "$EUID" -eq 0 ];then
    LOG_DIR="/var/log/backups"
else
    LOG_DIR="$HOME/.local/var/backups"
fi

LOG_FILE="$LOG_DIR/backup_script.log"



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
    echo "[$timestamp] [$level] $message"
}

banner(){

    if $IS_TERMINAL ;then
        echo "*******************************"
        echo "This is a simple backup script."
        echo "*******************************"
    fi
}


get_backup(){
    
    general_title=$1
    title=$2
    src=$3
    dst=$4
    ip=$5
    username=$6
    port=$7

    if $IS_TERMINAL;then

        echo "********************************"
        echo "[*] Starting Backup for $general_title [$title]"
        echo "[*] IP:PORT -> $ip:$port"
        echo "[*] User name -> $username"
        echo "[*] src-> $src"
        echo "[*] dst-> $dst"
    fi
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
        return 1
    else
        log "INFO" "$ip:$port connected."
        return 0
    fi

}

process_configs(){
    
    local config_file=$1

    if $IS_TERMINAL;then
        echo "[*] Proccessing [$1]"
    fi
    general_title=$(jq -r '.title' $config_file )
    titles=$(jq -r 'to_entries[] | select(.value | type == "object") | .key' $config_file)
    ip=$(jq -r '.ip' $config_file)
    username=$(jq -r '.username' $config_file)
    port=$(jq -r '.port' $config_file)
    

    # Check IP and PORT
    check_host $ip $port

    for title in ${titles[@]};do
        
        src=$(jq -r ".\"$title\".src" $config_file)
        dst=$(jq -r ".\"$title\".dst" $config_file)
        get_backup $general_title $title $src $dst $ip $username $port
    done
}

read_config(){
    
    shopt -s nullglob

    local json_files=( /home/gameover/bin/scripts/backup_script/*.json )
    
    if [ ${#json_files[@]} -eq 0 ];then
        
        if $IS_TERMINAL;then
            echo "[0] Json file found."
            shopt -u nullglob
            exit 1
        fi

    else
        if $IS_TERMINAL;then
            echo "[*] Found ${#json_files[@]} file"
        fi
    fi

    for name in ${json_files[@]};do
       process_configs "$name"
    done



    shopt -u nullglob
}


main(){
    
    setup_logging
    log "INFO" "Backup script started"
    banner
    read_config
    log "INFO" "Backup script finished"

}


main

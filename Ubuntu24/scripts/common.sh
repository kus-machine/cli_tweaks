#!/usr/bin/env bash

backup_file() {
    local file="$1"

    if [[ -e "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        echo "Backing up $file -> $backup"
        mv "$file" "$backup"
    fi
}
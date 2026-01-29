#!/bin/bash

# Define paths
CONFIG_DIR="/app/config"
DB_PATH="/app/data/tintin_users.db"

# Watch for modifications in the config directory
inotifywait -m -e modify "$CONFIG_DIR" --format '%w%f' |
while read FILE; do
    # Extract the config_id from the filename
    CONFIG_ID=$(basename "$FILE" .tintinrc)

    # Retrieve the username associated with this config_id
    USERNAME=$(sqlite3 "$DB_PATH" "SELECT username FROM users WHERE config_id='$CONFIG_ID';")

    # Read the updated file contents as hex for BLOB storage
    USER_SETTINGS_HEX=$(xxd -p "$FILE" | tr -d '\n')

    # Update the database with the new configuration as a BLOB
    sqlite3 "$DB_PATH" <<EOF
UPDATE users SET settings = X'$USER_SETTINGS_HEX' WHERE username = '$USERNAME';
EOF

    echo "$(date): Updated configuration for $USERNAME saved to database."
done

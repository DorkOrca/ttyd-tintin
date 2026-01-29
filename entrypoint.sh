#!/bin/bash

echo "$(date): Connection attempt by user" >> /app/logs/entrypoint.log

# Define database and config file paths
DB_PATH="/app/data/tintin_users.db"
CONFIG_DIR="/app/config"

# Set a flag for new user creation
IS_NEW_USER=false

# Function to escape single quotes in a string
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

#!/bin/bash

#!/bin/bash

# ANSI color code for red
RED='\033[31m'
# Reset color
NC='\033[0m'

echo -e "${RED}                     _   _       _        _____ _"
echo -e "${RED}                    | \\ | |_   _| | _____|  ___(_)_ __ ___"
echo -e "${RED}                    |  \\| | | | | |/ / _ \\ |_  | | '__/ _ \\"
echo -e "${RED}                    | |\\  | |_| |   <  __/  _| | | | |  __/"
echo -e "${RED}                    |_| \\_|\\__,_|_|\\_\\___|_|   |_|_|  \\___|${NC}"
echo
echo           "                  Welcome to the web-based tintin++ mud client."
echo
echo           "The username below will not be your characters name.  Its used to save your settings."
echo

# Prompt for username and ensure it’s not empty
while true; do
    echo -n "Enter your username: "
    read USERNAME
    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    if [ -n "$USERNAME" ]; then
        USERNAME=$(escape_sql "$USERNAME")
        break
    else
        echo "Username cannot be empty. Please enter a valid username."
    fi
done

# Check if the user exists in the database
USER_ROW=$(sqlite3 "$DB_PATH" "SELECT password, config_id FROM users WHERE username='$USERNAME';")

if [ -n "$USER_ROW" ]; then
    # Split the result into password and config_id
    STORED_PASSWORD=$(echo "$USER_ROW" | awk -F '|' '{print $1}')
    CONFIG_ID=$(echo "$USER_ROW" | awk -F '|' '{print $2}')

    # Prompt for password if the user exists
    while true; do
        echo -n "Enter your password: "
        read -s PASSWORD
        echo
        if [ -n "$PASSWORD" ]; then
            PASSWORD=$(escape_sql "$PASSWORD")
            break
        else
            echo "Password cannot be empty. Please enter a valid password."
        fi
    done

    # Verify password directly without additional quotes
    if [ "$PASSWORD" != "$STORED_PASSWORD" ]; then
        echo "Incorrect password. Exiting."
        exit 1
    fi
    echo "Welcome back, $USERNAME!"
else
    # Register a new user
    echo "User not found. Creating a new account."

    # Prompt for password and ensure it’s not empty
    while true; do
        echo -n "Choose a password: "
        read -s PASSWORD
        echo
        if [ -n "$PASSWORD" ]; then
            PASSWORD=$(escape_sql "$PASSWORD")
            break
        else
            echo "Password cannot be empty. Please enter a valid password."
        fi
    done

    # Generate a unique config_id for the new user
    CONFIG_ID=$(uuidgen)
    
    # Insert the new user, with manually escaped values
    sqlite3 "$DB_PATH" "INSERT INTO users (username, password, config_id) VALUES ('$USERNAME', '$PASSWORD', '$CONFIG_ID');"
    IS_NEW_USER=true
    echo "User registered successfully."
fi

# Set up the config file path with the unique identifier
CONFIG_FILE="$CONFIG_DIR/$CONFIG_ID.tintinrc"
USER_SETTINGS=$(sqlite3 "$DB_PATH" "SELECT hex(settings) FROM users WHERE username='$USERNAME';")

if [ -n "$USER_SETTINGS" ]; then
    echo "Loading existing configuration for $USERNAME."
    echo "$USER_SETTINGS" | xxd -r -p > "$CONFIG_FILE"
else
    echo "New user file creation..."
    echo "#nop welcome" > "$CONFIG_FILE"
fi

# Define a unique, temporary username based on CONFIG_ID
TEMP_USER="user_$(echo "$CONFIG_ID" | cut -c1-8)"

# Check if the user already exists, and only add if they don't
if id -u "$TEMP_USER" >/dev/null 2>&1; then
    echo "User $TEMP_USER already exists. Skipping user creation."
else
    # Add the temporary user and set ownership of the config file
    useradd -m "$TEMP_USER"
fi

# Set ownership and permissions of the config file
chown "$TEMP_USER":"$TEMP_USER" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

# Add save alias to write the configuration file
if [ "$IS_NEW_USER" = true ]; then
    echo "#alias {save} {sav;#write ${CONFIG_FILE}}" >> "$CONFIG_FILE"
fi
echo "#delay {0.01} {#read /app/config/defaultConfig}" >> "$CONFIG_FILE"

# Set terminal background to black and text color to white
tput setab 0  # Set background color to black
tput setaf 7  # Set text color to white

# Launch Tintin++ as the temporary user with a restricted PATH
su - "$TEMP_USER" -c "env PATH='/usr/local/bin' /usr/local/bin/tt++ '$CONFIG_FILE'"

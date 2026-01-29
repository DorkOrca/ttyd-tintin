if [ ! -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" <<EOF
    CREATE TABLE IF NOT EXISTS users (
        user_id INTEGER PRIMARY KEY,
        username TEXT UNIQUE,
        password TEXT,
        settings BLOB,
        config_id TEXT UNIQUE,
        last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
EOF
    echo "Database initialized."
    # Set permissions to restrict access to root only
    chmod 600 "$DB_PATH"
else
    echo "Database already exists."
fi

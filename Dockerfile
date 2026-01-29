FROM ubuntu:22.04

# Install build dependencies and other required packages
RUN apt update && \
    apt install -y build-essential libncurses5-dev libncursesw5-dev zlib1g-dev libpcre3-dev bash sqlite3 wget inotify-tools uuid-runtime sudo xxd && \
    wget -qO /usr/local/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 && \
    chmod +x /usr/local/bin/ttyd && \
    rm -rf /var/lib/apt/lists/*

# Copy Tintin++ source code into the container
COPY tt/src /app/tt/src

# Build Tintin++ from source
WORKDIR /app/tt/src
RUN ./configure && \
    make && \
    sudo make install

# Set up directories and copy scripts
WORKDIR /
RUN mkdir -p /app/data /app/config /app/logs

# Copy over the important files
COPY init_db.sh /app/init_db.sh
COPY entrypoint.sh /app/entrypoint.sh
COPY file_watcher.sh /app/file_watcher.sh
COPY defaultConfig /app/config/defaultConfig
COPY cleanup.sh /app/cleanup.sh
RUN chmod +x /app/init_db.sh /app/entrypoint.sh /app/file_watcher.sh /app/cleanup.sh
RUN chmod 444 /app/config/defaultConfig

# Environment variables for database paths
ENV DB_PATH="/app/data/tintin_users.db"
ENV CONFIG_DIR="/app/config"

# Initialize the SQLite database
RUN /app/init_db.sh

# Expose the port for ttyd (7681 by default)
EXPOSE 80

# Run the file watcher in the background and start ttyd with entrypoint.sh and custom CSS
CMD ["/bin/bash", "-c", "/app/init_db.sh & /app/cleanup.sh & /app/file_watcher.sh & ttyd --writable -p 80 -t scrollback=9999999 -t fontSize=16 -t term=xterm-256color -t 'theme={\"background\": \"#000000\", \"foreground\": \"#D2D2D2\", \"cursor\": \"#D2D2D2\", \"selection\": \"#D2D2D2\"}' /app/entrypoint.sh"]

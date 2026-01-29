# TinTin++ Web Container

A containerized web wrapper around [TinTin++](https://tintin.mudhalla.net), providing browser-based terminal access to the powerful MUD (Multi-User Dungeon) client.

## Features

- **Browser-based access**: Connect to MUDs from any device with a web browser
- **Full TinTin++ functionality**: Aliases, triggers, mapping, scripting, and more
- **User management**: SQLite-based authentication with persistent configuration
- **Multi-session support**: Connect up to 4 simultaneous MUD sessions
- **Auto-save**: Configuration changes are automatically persisted

## Prerequisites

- Docker

## Quick Start

1. **Build the Docker image:**
   ```bash
   docker build -t tintin-web .
   ```

2. **Create directories for persistent data:**
   ```bash
   mkdir -p /path/to/tintinData /path/to/tintinLogs
   ```

3. **Run the container:**
   ```bash
   docker run -d --restart unless-stopped \
     -p 80:80 \
     -v /path/to/tintinData:/app/data \
     -v /path/to/tintinLogs:/app/logs \
     tintin-web
   ```

   | Flag | Purpose |
   |------|---------|
   | `-d` | Run in background (detached) |
   | `--restart unless-stopped` | Auto-restart on reboot/crash |
   | `-p 80:80` | Map port 80 to host |
   | `-v .../tintinData:/app/data` | Persist user database and configs |
   | `-v .../tintinLogs:/app/logs` | Persist log files |

   **Important:** Mount `/app/data` and `/app/logs` to host directories to preserve user accounts and configurations when rebuilding the container.

4. **Access the client:**
   Open your browser to `http://localhost/`

5. **Register/Login:**
   Create an account or log in to access your TinTin++ session.

## Customization

### Configuring Your MUD Server

The default configuration connects to NukeFire MUD. To customize for your own MUD server, edit the `defaultConfig` file before building:

**Change the server address and port:**

```tintin
#alias {ses1} {#session {ses1} {your-mud-server.com} {port};#split}
#alias {ses2} {#session {ses2} {your-mud-server.com} {port};#split}
#alias {ses3} {#session {ses3} {your-mud-server.com} {port};#split}
#alias {ses4} {#session {ses4} {your-mud-server.com} {port};#split}
```

**Customize welcome messages:**

Edit the `welcomenotice` aliases to display your own branding and instructions:

```tintin
#alias {welcomenotice1} {#show Welcome to Your MUD Name}
#alias {welcomenotice2} {#show {\r};#show Enter '<169>ses1<099>' to connect;#show {\r}}
```

### Configuration File Reference

The `defaultConfig` file uses TinTin++ scripting syntax:

| Command | Description |
|---------|-------------|
| `#alias {name} {commands}` | Define command shortcuts |
| `#session {name} {host} {port}` | Connect to a MUD server |
| `#trigger {pattern} {response}` | Auto-respond to text patterns |
| `#event {EVENT_NAME} {action}` | React to client events |
| `#split` | Enable split-screen mode |

Full documentation: https://tintin.mudhalla.net/manual/

## Architecture

### Container Components

| File | Purpose |
|------|---------|
| `Dockerfile` | Ubuntu 22.04 base, builds TinTin++ from source, exposes port 80 |
| `entrypoint.sh` | User login/registration, launches TinTin++ session |
| `init_db.sh` | Creates SQLite schema for user management |
| `file_watcher.sh` | Monitors config changes, saves to DB as hex-encoded BLOBs |
| `cleanup.sh` | CPU usage monitor, kills runaway processes |
| `defaultConfig` | Default TinTin++ script with connection aliases |

### TinTin++ Source

The `tt/src/` directory contains the complete TinTin++ source code (~72K lines of C). Key modules include:

- `main.c` - Entry point
- `session.c`, `port.c` - Connection management
- `parse.c`, `tokenize.c` - Command parsing
- `trigger.c` - Trigger/alias system
- `terminal.c`, `vt102.c`, `screen.c` - Terminal emulation
- `telnet.c`, `ssl.c` - Network protocols
- `mapper.c` - MUD mapping functionality

### Database Schema

User data is stored in SQLite at `/app/data/tintin_users.db`:

```sql
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    username TEXT UNIQUE,
    password TEXT,
    settings BLOB,           -- Hex-encoded config file
    config_id TEXT UNIQUE,   -- UUID for per-user tracking
    last_modified TIMESTAMP
);
```

## Security: Locking Down Host and Container with iptables

When exposing this container to the internet, it's important to restrict both host access and container outbound traffic. The following setup uses iptables with the `DOCKER-USER` chain to control container networking while securing the host.

### Prerequisites

Install iptables-persistent to save rules across reboots:

```bash
sudo apt update
sudo apt install iptables-persistent
```

### Firewall Configuration Script

Create and run this script to configure iptables rules:

```bash
#!/bin/bash
# ==========================================================
# Combined iptables rules for Docker traffic + Host lockdown
# ==========================================================

# Make sure Docker is running to create its chains
sudo systemctl start docker
sleep 2  # Give Docker time to set up its chains

# -------------------------------
# 1. Create and reset DOCKER-USER chain
# -------------------------------
# This chain exists when Docker is running
if sudo iptables -L DOCKER-USER -n &>/dev/null; then
    sudo iptables -F DOCKER-USER
else
    echo "ERROR: DOCKER-USER chain doesn't exist. Make sure Docker is running."
    exit 1
fi

# -------------------------------
# 2. Set default policies
# -------------------------------
# Host default policies: drop everything by default
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD ACCEPT   # Keep FORWARD open for Docker
sudo iptables -P OUTPUT ACCEPT    # Allow host to make outbound connections

# -------------------------------
# 3. Host-level INPUT rules (traffic destined for the host)
# -------------------------------
# Flush existing INPUT chain rules
sudo iptables -F INPUT

# Accept loopback (localhost) traffic
sudo iptables -A INPUT -i lo -j ACCEPT

# Accept established and related connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH to the host (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP to the host (port 80)
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Drop all other inbound traffic to host (already handled by default policy, but explicit is nice)
sudo iptables -A INPUT -j DROP

# -------------------------------
# 4. DOCKER-USER chain (container-specific rules)
# -------------------------------
# Allow established and related connections in DOCKER-USER chain
sudo iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow DNS from containers (UDP port 53)
sudo iptables -A DOCKER-USER -i docker0 -p udp --dport 53 -j ACCEPT

# Allow NTP from containers (UDP port 123)
sudo iptables -A DOCKER-USER -i docker0 -p udp --dport 123 -j ACCEPT

# Allow outbound connections to specific IP ranges and ports
# Customize these for your MUD server(s)
# in this example the 76.17.0.0 is the docker subnets being used
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 76.17.0.0/16 --dport 4000 -j ACCEPT
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 76.17.0.0/16 --dport 4001 -j ACCEPT
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 76.17.0.0/16 --dport 4002 -j ACCEPT
# in this example the 10.0.1.100 is the ip address where the mud lives
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 10.0.1.100 --dport 4000 -j ACCEPT
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 10.0.1.100 --dport 4001 -j ACCEPT
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d 10.0.1.100 --dport 4002 -j ACCEPT

# Drop all other outbound traffic from docker0
sudo iptables -A DOCKER-USER -i docker0 -j DROP

# -------------------------------
# 5. Save rules (Ubuntu persistent)
# -------------------------------
sudo netfilter-persistent save
sudo netfilter-persistent reload
```

### What This Configuration Does

**Host Protection:**
- Drops all incoming traffic by default
- Allows SSH (port 22) and HTTP (port 80) only
- Permits established/related connections and localhost traffic

**Container Restrictions:**
- Allows DNS (port 53/UDP) and NTP (port 123/UDP) for basic functionality
- Restricts outbound connections to specific MUD server IPs and ports
- Drops all other outbound traffic from containers

### Customization

Modify the `DOCKER-USER` rules to allow your MUD server(s):

```bash
# Add rules for your MUD server IP and port
sudo iptables -A DOCKER-USER -i docker0 -p tcp -d YOUR.MUD.IP.ADDRESS --dport YOUR_PORT -j ACCEPT
```

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0).

TinTin++ is also GPL-3.0 licensed. The complete source code is included in the `tt/` directory as required by the license.

## Credits

- **TinTin++**: https://tintin.mudhalla.net - The powerful MUD client this project wraps
- **ttyd**: Terminal sharing over the web
- **NukeFire MUD**: Default server configuration (tdome.nukefire.org:4000)

## Resources

- [TinTin++ Manual](https://tintin.mudhalla.net/manual/)
- [TinTin++ Scripts](https://tintin.mudhalla.net/scripts/)
- [MUD Connector](http://www.mudconnect.com/) - Find MUDs to connect to

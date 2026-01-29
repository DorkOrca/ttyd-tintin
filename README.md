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

2. **Run the container:**
   ```bash
   docker run -p 80:7681 tintin-web
   ```

3. **Access the client:**
   Open your browser to `http://localhost/`

4. **Register/Login:**
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

## Building TinTin++ from Source

If you need to modify TinTin++ itself:

```bash
cd tt/src
./configure
make
sudo make install
```

**Clean build artifacts:**
```bash
cd tt/src
make clean       # Remove .o files and binary
make distclean   # Also remove generated Makefiles and config
```

**Build dependencies:** libpcre3, zlib1g, libncurses5/w, gnutls

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

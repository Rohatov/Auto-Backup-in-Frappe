# Frappe Auto-Backup System

A production-ready, modular Bash-based backup solution for Frappe/ERPNext that automatically creates daily database backups and sends them securely to a private Telegram channel.

## Features

- 🔄 **Automated Daily Backups** - Cron-based scheduling
- 📦 **Compression** - Gzip compression for efficient storage
- 📱 **Telegram Integration** - Automatic upload to private channel
- 🔒 **Security First** - No hardcoded secrets, minimal permissions
- 🔁 **Retry Mechanism** - Exponential backoff for failed uploads
- 📊 **Logging** - Comprehensive logging with timestamps
- 🧪 **Dry-Run Mode** - Test without making changes

## Quick Start

### 1. Clone and Install

```bash
cd /path/to/frappe-bench
git clone https://github.com/your-repo/Auto-Backup-in-Frappe.git
cd Auto-Backup-in-Frappe
./scripts/install.sh
```

### 2. Configure

Edit `.env` with your settings:

```bash
nano .env
```

Required configuration:

| Variable | Description | Example |
|----------|-------------|---------|
| `FRAPPE_BENCH_PATH` | Path to frappe-bench | `/home/frappe/frappe-bench` |
| `SITE_NAME` | Your Frappe site name | `mysite.localhost` |
| `BACKUP_DIR` | Where to store backups | `/home/frappe/backups` |
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | `123456:ABC...` |
| `TELEGRAM_CHAT_ID` | Channel/chat ID | `-1001234567890` |

### 3. Set Up Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow instructions
3. Copy the **bot token** to your `.env`
4. Create a private channel
5. Add your bot as **admin** to the channel
6. Get the channel ID:
   - Forward a message from the channel to **@userinfobot**
   - The ID will be like `-1001234567890`

### 4. Test (Dry Run)

```bash
./src/backup_runner.sh --dry-run
```

### 5. Run Actual Backup

```bash
./src/backup_runner.sh
```

### 6. Schedule Daily Backups

```bash
# Default: 23:55 PM daily
./scripts/setup_cron.sh

# Custom time (e.g., 3:30 AM)
./scripts/setup_cron.sh 3 30
```

## Project Structure

```
Auto-Backup-in-Frappe/
├── src/
│   ├── utils.sh           # Logging & helper functions
│   ├── backup.sh          # Frappe backup logic
│   ├── telegram.sh        # Telegram Bot API integration
│   └── backup_runner.sh   # Main orchestrator
├── scripts/
│   ├── install.sh         # Installation script
│   └── setup_cron.sh      # Cron configuration
├── .env.example           # Configuration template
└── README.md
```

## Usage

```bash
# Run backup with default config
./src/backup_runner.sh

# Dry run (test without changes)
./src/backup_runner.sh --dry-run

# Use custom config file
./src/backup_runner.sh --config /path/to/.env

# Show help
./src/backup_runner.sh --help
```

## Configuration Options

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `FRAPPE_BENCH_PATH` | ✅ | - | Path to frappe-bench installation |
| `SITE_NAME` | ✅ | - | Frappe site name |
| `BACKUP_DIR` | ✅ | - | Directory to store backups |
| `TELEGRAM_BOT_TOKEN` | ✅ | - | Telegram bot token |
| `TELEGRAM_CHAT_ID` | ✅ | - | Telegram channel/chat ID |
| `LOG_FILE` | ❌ | - | Path to log file |

## Security Best Practices

- ✅ All credentials stored in `.env` file only
- ✅ `.env` file excluded from git via `.gitignore`
- ✅ Scripts have `700` permissions (owner only)
- ✅ `.env` file has `600` permissions
- ✅ Backup files have `600` permissions
- ✅ No secrets in command-line arguments

## Troubleshooting

### Backup fails with "bench not found"
Ensure the `bench` command is in PATH. Try running from the frappe user:
```bash
su - frappe
./src/backup_runner.sh
```

### Telegram upload fails
1. Verify bot token is correct
2. Ensure bot is admin in the channel
3. Check file size (max 50MB for Bot API)
4. Test connection: check logs for error details

### Permission denied
```bash
chmod +x src/*.sh scripts/*.sh
chmod 600 .env
```

## License

MIT License - see [LICENSE](LICENSE) file.
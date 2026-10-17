# Marketplace Monitor - Facebook Marketplace Alert System

A Ruby application that monitors Facebook Marketplace listings and sends email alerts when new items matching your search criteria are posted.

## Prerequisites

- Ruby 4.0+ (or Docker)
- SQLite3 (bundled with Docker image)
- A SociaVault API account (https://sociavault.com)
- An email account with SMTP access

## Quick start with Docker (recommended)

```bash
# 1. Copy the env template and fill in your values
cp .env.example .env
# Edit .env with your SOCIAVAULT_API_KEY, SMTP settings, and searches

# 2. Build and run (executes all saved searches once)
docker compose up

# 3. For continuous monitoring via cron, add to crontab on the host:
# */30 * * * * cd /path/to/fbm_alerter && docker compose run --rm marketplace-monitor exec
```

### Docker commands

| Command | Description |
|---------|-------------|
| `docker compose up` | Build image, migrate DB, run all saved searches once |
| `docker compose run --rm marketplace-monitor list` | List saved searches |
| `docker compose run --rm marketplace-monitor add -q bike -lat 30.2677 -long -97.7475 --min 100 --max 500 --email you@example.com` | Add a new saved search |
| `docker compose down -v` | Stop and remove the data volume (deletes the SQLite database) |

Data persists in a Docker named volume (`marketplace-monitor-data`) at `/data/marketplace_monitor.db`.

## Local setup (without Docker)

```bash
# 1. Install dependencies
bundle install

# 2. Copy env and configure
cp .env.example .env
# Edit .env with your API key and SMTP credentials

# 3. Run setup (migrates DB, validates config)
./setup.sh

# 4. Add searches and run
bundle exec ruby main.rb add -q bike -lat 30.2677 -long -97.7475 --min 100 --max 500 --email you@example.com
bundle exec ruby main.rb exec
```

## Configuration

Create a `.env` file (copy from `.env.example`). Required settings:

- `SOCIAVAULT_API_KEY` — from https://sociavault.com/dashboard
- `EMAIL_FROM` / `EMAIL_TO` — sender and recipient email addresses
- `SMTP_ADDRESS` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` — SMTP credentials (Gmail app password recommended)

### Saved searches

Searches are stored in the SQLite database. Add them via the CLI:

```bash
bundle exec ruby main.rb add -q "mountain bike" -lat 40.7128 -long -74.0060 --min 50 --max 300 --radius 25 --cond used_good --del shipping --email you@example.com
```

Or set them in `.env` via the `SEARCHES` variable (format: `query|lat|lng|min|max|[radius]|[condition]|[delivery]`).

## Testing

```bash
bundle exec rspec
```

Integration tests mock the SociaVault API with WebMock — no real API calls are made.

## CLI commands

- `add` — Add a new saved search
- `delete ID` — Delete a saved search by ID
- `exec` — Execute all saved searches and send alerts for new listings
- `list` — List all saved searches
- `search` — Run a one-off search (not saved)

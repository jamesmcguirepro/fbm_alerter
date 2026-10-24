# Marketplace Monitor - Facebook Marketplace Alert System

A Ruby application that monitors Facebook Marketplace listings and sends email alerts when new items matching your search criteria are posted.

## Prerequisites

- Ruby 4.0+ (or Docker)
- SQLite3 (bundled with Docker image)
- A SociaVault API account (https://sociavault.com)
- An email account with SMTP access

## Quick start with Docker (recommended)

The image is published on Docker Hub as [`trailstack/fbm_alerter`](https://hub.docker.com/r/trailstack/fbm_alerter), so there is nothing to build:

```bash
# 1. Copy the env template and fill in your values
cp .env.example .env
# Edit .env with your SOCIAVAULT_API_KEY and SMTP settings

# 2. Start the web GUI (http://localhost:9292) and the daily scheduler
docker compose up -d

# 3. (optional) run the searches now instead of waiting for the scheduler
docker compose run --rm marketplace-monitor exec
```

`web` and `scheduler` share one SQLite database, so a run triggered from the CLI shows up in the GUI straight away.

`web` is the only service that runs database migrations. `scheduler` and the one-shot `marketplace-monitor` tool wait for `web` to be healthy, which means migrations have finished, so two containers never race on `schema_migrations`.

### Docker commands

| Command | Description |
|---------|-------------|
| `docker compose pull` | Pull the published image |
| `docker compose up -d` | Start the web GUI and the daily scheduler |
| `docker compose up -d web` | Start just the web GUI |
| `docker compose run --rm marketplace-monitor exec` | Run all saved searches once (waits for web's migrations) |
| `docker compose run --rm marketplace-monitor list` | List saved searches |
| `docker compose run --rm marketplace-monitor add -q bike --lat 30.2677 --long=-97.7475 --min 100 --max 500 --email you@example.com` | Add a new saved search |
| `docker compose run --rm marketplace-monitor delete 3` | Delete a saved search by ID |
| `docker compose logs -f scheduler` | Watch the scheduler (results of each run) |
| `docker compose down` | Stop the containers (data is kept) |
| `docker compose down -v` | Stop and remove the data volume (deletes the SQLite database) |

Data persists in the `data` folder next to the compose file, bind-mounted at `/app/storage` (SQLite file: `data/development.sqlite3`).

> `marketplace-monitor` is a one-shot job (it runs the searches, then exits) and lives in the optional `tools` profile, so `docker compose up` and Container Manager's project start skip it. Run it explicitly with `docker compose run --rm marketplace-monitor exec` for a manual run — its normal exit would otherwise be reported by Container Manager as an unexpected stop.

### Choosing an image tag

`docker-compose.yml` runs `trailstack/fbm_alerter:${IMAGE_TAG:-1.0.13}` — pinned to a version by default, so redeploys are reproducible and a rollback is a one-line change. Override it in `.env` if you want a different tag:

```bash
IMAGE_TAG=latest
```

### Building the image locally

To run your own changes instead of the published image, use the build override (it swaps the `image:` back to a local `build: .`):

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.build.yml run --rm marketplace-monitor exec
```

### Publishing a new image (maintainers)

The image is multi-architecture (`linux/amd64` + `linux/arm64`) so it runs on both x86 and ARM hosts, including Synology NAS units. Build and push with Buildx:

```bash
docker buildx create --use --name multiarch   # one-time
docker login

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --provenance=false \
  -t trailstack/fbm_alerter:1.0.13 \
  -t trailstack/fbm_alerter:latest \
  --push .
```

`--provenance=false` keeps the image a clean two-manifest list: the `unknown/unknown` attestation entries Buildx adds by default confuse older Docker engines (Synology's, for instance). The image intentionally contains no secrets or data — `.env` and `storage/*.sqlite3*` are excluded by `.dockerignore`.

### Running on Synology/QNAP NAS

DSM 7.2+ ships this as **Container Manager** (the old "Docker" package, renamed). Two ways to deploy:

**Container Manager GUI**

1. Package Center → install **Container Manager**.
2. File Station → create a project folder on a shared folder, e.g. `/volume1/docker/fbm_alerter`, and copy in `docker-compose.yml`.
3. Create a `.env` in that folder (see [Configuration](#configuration)).
4. Container Manager → **Project** → **Create**, point it at the folder, and start it.
5. The project starts `web` and `scheduler`. `marketplace-monitor` is a one-shot job in the optional `tools` profile, so the project start leaves it alone and its normal exit is not reported as an unexpected stop.

**SSH / CLI** (DSM 7.2.1+ with a current Container Manager):

```bash
cd /volume1/docker/fbm_alerter
docker compose up -d          # web + scheduler
```

The compose file bind-mounts the database into a `data` folder next to it, so it is easy to back up:

```yaml
    volumes:
      - /volume1/docker/fbm_alerter/data:/app/storage
```

Create that `data` folder first (File Station). Every service must mount the **same** host folder, or they will each see a different, empty database.

### Scheduling (run once a day)

The `scheduler` service runs the searches itself once a day at `SCHEDULE_AT` (default `20:00`) in the container's `TZ`. Nothing external is needed — no host cron, no Docker socket access.

It does **not** run just because the container started. Before each pass it checks the `monitor_runs` table for a full run already made today:

- already ran today → wait for tomorrow's scheduled time
- no run today, before the scheduled time → wait for today's time
- no run today, past the scheduled time → run immediately (catch-up)

That means restarting or recreating the container costs nothing unless a scheduled run was genuinely missed. A manual “Run all searches now”, or `docker compose run --rm marketplace-monitor exec`, also counts as today's full run, so the scheduler won't repeat it. A single-search “Run now” does not count.

To change the time, set `SCHEDULE_AT` in `.env` (24-hour `HH:MM`) and recreate the container. The value is interpreted in `TZ`.

It uses the same code path as `docker compose run --rm marketplace-monitor exec`, so results match a manual run.

`web` is the only service that runs migrations, and it does so before serving HTTP. Both `scheduler` and `marketplace-monitor` wait for `web` to be healthy, so they only start once the database schema is ready. This is also why `docker compose up -d` does not produce a `schema_migrations` race between the two containers.

The image carries a healthcheck for the web GUI (port 9292), and Docker applies it to every container from the image. Since only `web` serves that port, `scheduler` and `marketplace-monitor` override it with `healthcheck: test: ["NONE"]` — otherwise they get reported as unhealthy for no reason.

Prefer an external scheduler? Point your host at the run command and drop the `scheduler` service. On a Synology NAS: **Control Panel → Task Scheduler → Create → Scheduled Task → User-defined script** (run as `root`), daily:

```sh
cd /volume1/docker/fbm_alerter && /usr/local/bin/docker compose up -d web && /usr/local/bin/docker compose run --rm marketplace-monitor exec
```

On a generic Linux host:

```cron
0 8 * * * cd /path/to/fbm_alerter && docker compose up -d web && docker compose run --rm marketplace-monitor exec >> /path/to/fbm_alerter/cron.log 2>&1
```

Set `TZ` in `.env` so the container's timestamps, "today" counts, and the scheduler's run time line up.

## Web GUI

The app includes a Sinatra-based web GUI (no auth, intended for LAN use). It reads and writes the same SQLite database as the CLI, so a search added from either place shows up in both.

![Marketplace Monitor dashboard](docs/web-dashboard.png)

Start it with `docker compose up -d web` and visit `http://<nas-ip>:9292` — the NAS hostname works too, and you can restrict accepted hostnames with `PERMITTED_HOSTS` (see Configuration).

| Page | What it shows |
|------|---------------|
| `/dashboard` | At-a-glance counts, credit balance, "Run all searches now", recent listings |
| `/searches` | Create, edit, pause/resume, delete, and run individual searches |
| `/listings` | Paginated table of every listing seen, filterable by title and sold status |
| `/alerts` | Alert history — which search matched which listing, and when it was sent |
| `/settings` | Configuration summary (secrets masked), test email, email preview |

A few things worth knowing:

- **Time zone** — the picker in the header applies to every page and is remembered for the session (Pacific by default), so timestamps read the way you expect without the container's clock mattering.
- **Dry run badge** — with `DRY_RUN=true` a "Dry run" badge appears in the header, and every search becomes a no-op: you can click around, run searches, and check the email layout without spending credits.
- **Fresh, relevant results** — each search asks for ads from the **last 7 days** (`DATE_LISTED`, configurable), in SociaVault's default relevance order, then lists them newest-first using each ad's own `creation_time`. It deliberately avoids SociaVault's `sort_by`: that order makes Facebook ignore the query and hand back the newest listings anywhere, so "husqvarna te 300" returns Camrys. Listings are kept only when their title contains at least one query keyword (nicknames like `husky` → `husqvarna` and `chevy` → `chevrolet` count), so filler is never stored or alerted. Paging stops at the first page with no title match, which is usually page 1 or 2. Duplicates are deduped per search, so a daily run only alerts on genuinely new ads. Every page fetched costs a credit, with a 3-page ceiling.
- **Dashboard** — every card is a link. "Credits left" is read live from SociaVault (that call is free) and turns amber once the balance gets low. "Run all searches now" streams the monitor's log into a modal, so a run is visible without watching the container. In the recent-listings table the whole row opens the ad, and the Search column links back to the search that produced it.
- **Searches** — each row can be run on its own ("Run now" opens the log in a modal), paused/resumed, edited, or deleted. The Calls column counts SociaVault API calls (one call = one credit) plus the date of the last run, and the Location cell shows the resolved place name with the coordinates underneath. Saving an edit forks a new search and pauses the original, so past listings keep pointing at the search that actually found them; deleting removes a search from the lists but keeps its alert and run history, so the Alerts page stays complete.
- **Listings** — thumbnails, prices, the resolved location and the search each listing came from; rows link to the Facebook ad.
- **Alerts** — send times are shown to the second, since a single run can send several alerts within the same minute. Each alert ends with the host that sent it, taken from the container's `hostname:` in `docker-compose.yml`.
- **Settings** — masked API key, SMTP settings, database path and environment, plus a test email form. "Preview alert email" renders the real alert template in a new tab from listings already in the database, so the layout can be checked without sending mail or spending a credit.

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
bundle exec ruby main.rb add -q bike --lat 30.2677 --long=-97.7475 --min 100 --max 500 --email you@example.com
bundle exec ruby main.rb exec

# 5. Start the web GUI (http://localhost:9292)
bundle exec puma -b tcp://0.0.0.0:9292 config.ru
```

## Configuration

Create a `.env` file (copy from `.env.example`). Required settings:

- `SOCIAVAULT_API_KEY` — from https://sociavault.com/dashboard
- `EMAIL_FROM` — sender ("From") address for alert emails (recipients are set per saved search)
- `SMTP_ADDRESS` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` — SMTP credentials (Gmail app password recommended)

Optional:

- `DATE_LISTED` — how far back each search looks, sent to SociaVault as `date_listed`: one of `all`, `1`, `7`, `30`, `last_24_hours`, `last_7_days`, `last_30_days`. Unset means `last_7_days`, which survives a skipped day. Every page fetched costs a credit, so a narrow window is cheapest — but with a daily run it also has no margin, and ads posted while a run was skipped are never seen. An unrecognised value warns at startup and falls back to the default. Changing it needs the containers recreated.
- `DRY_RUN` — `true` to make searches a no-op: the pipeline runs but nothing is sent to SociaVault and no credits are spent. Useful for exercising the UI or checking a change without spending credits; the header shows a "Dry run" badge while it is on.
- `IMAGE_TAG` — which `trailstack/fbm_alerter` image tag `docker-compose.yml` runs (default `1.0.13`).
- `PERMITTED_HOSTS` — comma-separated Host allow-list for the web GUI. Unset (the default) accepts any Host, so the GUI is reachable by the NAS hostname or IP; set it to restrict access (e.g. `fbm-nas.local,192.168.1.50`).
- `SCHEDULE_AT` — daily full-run time for the `scheduler`, as 24-hour `HH:MM` in the container's `TZ` (default `20:00`). Restarting the container does not trigger a run; if today's scheduled pass was missed, the next start catches up. An invalid value warns and falls back to the default.
- `TZ` — the container's time zone (e.g. `America/Los_Angeles`), used for log timestamps, "today" counts, the scheduler's `SCHEDULE_AT`, and the listing dates in alert emails. The web GUI's time-zone picker is separate and only affects what it displays.

### Saved searches

Searches are stored in the SQLite database. Add them via the CLI:

```bash
bundle exec ruby main.rb add -q "mountain bike" --lat 40.7128 --long=-74.0060 --min 50 --max 300 --radius 25 --cond used_good --del shipping --email you@example.com
```

> Use `--long=-74.0060` (with `=`) for negative longitudes — a space-separated value
> starting with `-` is parsed as a command-line switch.

Each search stores its own alert recipient (`--email`), which is where notifications for that search are sent.

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

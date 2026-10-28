# FBM Alerter — Agent Guide

## Build commands

### Local development

```bash
# Install gems
bundle install

# Run migrations
rake db:migrate

# Roll back one migration step
rake db:rollback

# Check migration status
rake db:status

# Run the web GUI (Sinatra / Puma)
RUBY_ENV=development ruby -r ./config/boot -r puma -r sinatra/base -e 'run MarketplaceApp'
# or simply via config.ru:
ruby -I. -r ./config/boot -r puma -r sinatra/base config.ru

# Run the CLI
ruby main.rb --help
ruby main.rb add --query "PS5" --city "Austin TX" --email "you@example.com"
ruby main.rb exec          # run all saved searches
ruby main.rb schedule      # run saved searches daily at SCHEDULE_AT
ruby main.rb list          # list saved searches
ruby main.rb delete <id>   # remove a saved search
ruby main.rb search --query "PS5" --city "Austin TX"  # ad-hoc search
```

### Docker

```bash
# Build image locally (uses docker-compose.build.yml)
docker compose -f docker-compose.build.yml build

# Run the web GUI
docker compose up -d web          # http://<host>:9292

# Run the daily scheduler
docker compose up -d scheduler

# Ad-hoc CLI (runs once and exits)
docker compose run --rm marketplace-monitor exec
docker compose run --rm marketplace-monitor add --query "PS5" --city "Austin TX" --email "you@example.com"
docker compose run --rm marketplace-monitor list
docker compose run --rm marketplace-monitor search --query "PS5" --city "Austin TX"
```

### Tests

```bash
# Run the full suite
rspec

# Single file or directory
rspec spec/lib/monitor_spec.rb
rspec spec/models/

# Pattern match within specs
rspec spec --tag ~slow
```

### Linting

```bash
rubocop
rubocop -a  # auto-correct
```

---

## Module layout

```
├── main.rb                   # CLI entry point — boots, delegates to CLI.start
├── config.ru                 # Web entry point — boots, runs MarketplaceApp
├── config/
│   ├── boot.rb               # Shared boot: env setup, Zeitwerk, DB connect
│   └── database.yml          # ActiveRecord DB config per environment
├── app/
│   ├── marketplace_app.rb    # Sinatra::Base — the web app root
│   ├── helpers.rb            # ViewHelpers module (erb helpers)
│   ├── routes/               # Route modules (Sinatra groups / files)
│   │   ├── dashboard.rb
│   │   ├── listings.rb
│   │   ├── searches.rb
│   │   ├── alerts.rb
│   │   └── settings.rb
│   └── views/                # ERB templates
│       ├── layout.erb
│       ├── error.erb
│       ├── dashboard/
│       ├── listings/
│       ├── searches/
│       ├── alerts/
│       └── settings/
├── lib/                      # Business logic (autoloaded via Zeitwerk)
│   ├── cli.rb                # Thor-based CLI commands
│   ├── config.rb             # App config reader
│   ├── database.rb           # DB connection helper
│   ├── geocoder.rb           # Nominatim geocoding
│   ├── market_place_monitor.rb  # Core search & alert execution
│   ├── search_service.rb     # API calls to SociaVault
│   ├── listing_matcher.rb    # Listing-to-search matching logic
│   ├── scheduler.rb          # Daily cron-like scheduler
│   ├── email_service.rb      # Email dispatch
│   ├── mailer.rb             # Email template builder
│   ├── price_formatter.rb    # Price formatting
│   ├── distance.rb           # Haversine distance calculation
│   └── search_form.rb        # Form validation
├── models/                   # ActiveRecord models (autoloaded)
│   ├── listing.rb
│   ├── saved_search.rb
│   ├── alert.rb
│   ├── alert_record.rb
│   ├── monitor_run.rb
│   ├── search_run.rb
│   ├── geocode_cache_entry.rb
│   └── credit_snapshot.rb
├── dtos/                     # Data transfer objects (autoloaded)
│   ├── search_object.rb
│   ├── search_result.rb
│   └── listing_object.rb
├── db/migrate/               # ActiveRecord migrations
├── spec/                     # RSpec tests (mirror structure)
│   ├── spec_helper.rb
│   ├── lib/
│   ├── models/
│   └── dtos/
├── public/                   # Static assets
│   ├── css/app.css
│   └── js/htmx.min.js
├── storage/                  # SQLite databases (per env)
└── script/release            # Release helper script
```

**Boot sequence:** `config/boot.rb` is the single boot path — loaded by both `main.rb` (CLI) and `config.ru` (web). It sets up:

1. **Zeitwerk** autoloader for `lib/`, `models/`, `dtos/`
2. **Database connection** via `Database.connect` (uses `RUBY_ENV`)
3. SQLite pragmas (`WAL`, `busy_timeout`)
4. `VERSION` constant

---

## Conventions

### General

- Every file starts with `# frozen_string_literal: true`.
- No framework generators — files are created manually.
- One class/module per file, file name = snake_case, class = PascalCase.
- Zeitwerk infers names automatically; exceptions are in `boot.rb`:
  ```ruby
  loader.inflector.inflect('cli' => 'CLI', 'monitor' => 'MarketplaceMonitor')
  ```

### Routing (Sinatra)

- Each `app/routes/*.rb` file defines a Sinatra subclass with its own `get`/`post`/`patch`/`delete` handlers.
- Routes mount at their own prefix (e.g. `/searches`) and the app mounts them under `/`.
- Views live under `app/views/<route_name>/` matching the route file.

### Models

- ActiveRecord models use the **Discard** gem for soft deletes (`deleted_at` column).
- Model files are in `models/`, autoloaded by Zeitwerk.
- All models inherit from `ApplicationRecord` (convention) or `ActiveRecord::Base`.

### DTOs

- Plain Ruby value objects in `dtos/` for passing data between layers (e.g. `SearchObject`, `ListingObject`, `SearchResult`).
- No persistence logic — they are data bags only.

### CLI

- Built on **Thor**, invoked via `ruby main.rb <command>`.
- Commands are class methods on `CLI` (inherits `Thor`).
- Use `option` class methods for flag declarations at the top of each command.
- `exit_on_failure? = true` — Thor exits on errors automatically.

### Environment

- `RUBY_ENV` controls the database (development / test / production).
- `.env` is loaded via `dotenv` in `boot.rb`; `.env.example` documents required keys.
- `VERSION` is set in `boot.rb` and returned by the `/health` endpoint.

### Testing (RSpec)

- `spec/spec_helper.rb` pins `RUBY_ENV=test` **before** loading `dotenv` and the app, to prevent tests from touching the development database.
- **DatabaseCleaner** truncates the test DB before each example.
- **WebMock** disables all real network calls; stub them explicitly.
- Test DB files live in `storage/test.sqlite3`.
- Specs mirror the source layout: `spec/lib/`, `spec/models/`, `spec/dtos/`.

### Docker

- Three compose services: **web** (GUI), **scheduler** (daily runs), **marketplace-monitor** (ad-hoc CLI).
- The **web** service runs migrations before accepting traffic; the scheduler and monitor wait for web's health check.
- SQLite storage is mounted from the host (`/volume1/docker/fbm_alerter/data:/app/storage`).
- `docker-compose.build.yml` is used for local builds (no `--rm` groups); the published image is `trailstack/fbm_alerter`.

### Database

- SQLite with WAL mode and a 5-second busy timeout (set in `boot.rb`).
- Migrations run via Rake (`rake db:migrate`), driven by `ActiveRecord::Tasks::DatabaseTasks`.
- `config/database.yml` uses ERB templating for per-environment settings.

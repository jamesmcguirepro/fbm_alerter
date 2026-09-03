# Marketplace Monitor - Facebook Marketplace Alert System

A Ruby application that monitors Facebook Marketplace listings and sends email alerts when new items matching your search criteria are posted.

## Features

- 🔍 **Automated Searches**: Monitor multiple search queries simultaneously
- 📧 **Email Alerts**: Get notified instantly when new listings are found
- 💾 **Smart Tracking**: Never miss a listing; remembers what's been sent
- ⏰ **Flexible Scheduling**: Run on demand, as a daemon, or via cron
- 🎯 **Advanced Filters**: Price range, condition, location radius, delivery method
- 📊 **SQLite Database**: Local storage with no external dependencies

## Prerequisites

- Ruby 3.2+
- SQLite3
- A SociaVault API account (https://sociavault.com)
- An email account with SMTP access

## Installation

### 1. Clone or Download the App

```bash
git clone <repository-url> marketplace_monitor
cd marketplace_monitor
```

### 2. Install Dependencies

```bash
gem install bundler
bundle install
```

Or if you don't have bundler:

```bash
gem install httparty mail dotenv sqlite3 chronic_duration whenever
```

### 3. Set Up Configuration

Copy the example environment file and edit with your settings:

```bash
cp .env.example .env
```

Then edit `.env` with:

- Your SociaVault API key
- Email settings (Gmail or other SMTP provider)
- Search queries
- Schedule interval

**Example `.env`:**

```env
SOCIAVAULT_API_KEY=sk_live_xxxxxxxxxxxxx
EMAIL_FROM=alerts@example.com
EMAIL_TO=you@example.com,friend@example.com
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SEARCHES=mountain bike|40.7128|-74.0060|100|500|25;bicycle|34.0522|-118.2437|50|300
SCHEDULE_INTERVAL=30m
```

### 4. Initialize the Database

```bash
ruby marketplace_monitor.rb init
```

This creates `marketplace_monitor.db` to track listings and alert history.

## Configuration

### Getting Your SociaVault API Key

1. Visit https://sociavault.com/dashboard
2. Create an account or sign in
3. Copy your API key from the dashboard
4. Add to `.env` as `SOCIAVAULT_API_KEY`

### Email Configuration

#### Gmail (Recommended)

1. Enable 2-factor authentication on your Gmail account
2. Generate an app password: https://myaccount.google.com/apppasswords
3. Use settings:
   ```env
   SMTP_ADDRESS=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USERNAME=your_email@gmail.com
   SMTP_PASSWORD=your_app_password
   ```

#### SendGrid

```env
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
```

#### AWS SES

```env
SMTP_ADDRESS=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=your_ses_username
SMTP_PASSWORD=your_ses_password
```

### Configuring Searches

Format: `query|latitude|longitude|min_price|max_price|[radius_km]|[condition]|[delivery_method]`

Multiple searches separated by semicolons.

**Examples:**

```env
# Single search: Bikes $100-500 in Austin within 65km
SEARCHES=bike|30.2677|-97.7475|100|500|65

# Multiple searches
SEARCHES=bike|30.2677|-97.7475|100|500;mountain bike|40.7128|-74.0060|50|300|25|used_good|shipping

# With condition and delivery filters
SEARCHES=furniture|40.7128|-74.0060|0|1000|10|used_good|local_pickup
```

**Parameters:**
- `query` - Search keyword (e.g., "bike", "furniture")
- `latitude`, `longitude` - Center location coordinates
- `min_price`, `max_price` - Price range
- `radius_km` - Search radius in kilometers (default: 65)
- `condition` - Optional: new, used_like_new, used_good, used_fair
- `delivery_method` - Optional: all, local_pickup, shipping

**Finding Coordinates:**

Use Google Maps:
1. Right-click a location
2. Click the coordinates at the top
3. Copy latitude and longitude

Or find coordinates online:
- https://www.latlong.net/
- https://www.gps-coordinates.net/

## Usage

### Run Once (Manual)

Execute a single search cycle:

```bash
ruby marketplace_monitor.rb run
```

This will:
1. Query the API for all searches
2. Store new listings in the database
3. Send email for any new listings
4. Mark emails as sent

### Run as Daemon (Continuous)

Start a long-running process that searches at regular intervals:

```bash
ruby marketplace_monitor.rb daemon
```

The interval is controlled by `SCHEDULE_INTERVAL` in `.env` (default: 30m).

Press `Ctrl+C` to stop.

### Schedule with Cron

For production deployments, use cron to run periodically:

```bash
# Edit your crontab
crontab -e
```

Add a line to run every 30 minutes:

```bash
*/30 * * * * cd /path/to/marketplace_monitor && ruby marketplace_monitor.rb run >> /var/log/marketplace_monitor.log 2>&1
```

Or every hour:

```bash
0 * * * * cd /path/to/marketplace_monitor && ruby marketplace_monitor.rb run >> /var/log/marketplace_monitor.log 2>&1
```

### Initialize Database

```bash
ruby marketplace_monitor.rb init
```

Creates the SQLite database and tables.

## How It Works

1. **First Run**: The app fetches listings and stores them
2. **Subsequent Runs**: New listings trigger email alerts
3. **Tracking**: The database remembers which listings have been emailed
4. **Smart Updates**: Listings marked as sold are skipped

### Database Schema

**listings** table:
- `id` - Marketplace listing ID (unique)
- `title` - Listing title
- `price` - Price in local currency
- `location` - Listing location
- `url` - Direct link to Facebook listing
- `image_url` - Primary product image
- `search_query` - Which search found this
- `first_seen_at` - When we first saw it
- `last_seen_at` - When we last verified it exists
- `is_sold` - Whether item is marked as sold

**alerts_sent** table:
- Tracks which listings have had alerts emailed
- Prevents duplicate emails for the same listing

## Troubleshooting

### "API Error: Invalid API key"

- Verify your API key in `.env` matches your SociaVault dashboard
- Check it starts with `sk_live_`
- Regenerate if needed at https://sociavault.com/dashboard

### "Insufficient credits"

- The API uses 1 credit per search request
- Check your credit balance at https://sociavault.com/dashboard
- Add credits to your account

### "Bad parameters" error

- Verify latitude/longitude are decimal numbers (e.g., 40.7128, not 40°42'46")
- Ensure price ranges are positive integers
- Check that radius_km is a number

### Emails not sending

1. Check SMTP credentials in `.env`
2. For Gmail, ensure you're using an app password (not your Gmail password)
3. Enable "Less secure app access" if needed (not recommended long-term)
4. Verify sender email address is correct
5. Check firewall/network isn't blocking SMTP port 587

### Database locked error

- Stop all instances of the app
- Delete `marketplace_monitor.db` and run `ruby marketplace_monitor.rb init`

### Missing required environment variables

```bash
# Make sure you have a .env file with all required variables
# Copy from .env.example and fill in your values
cp .env.example .env
nano .env
```

## Advanced Usage

### Logging

Redirect output to a log file:

```bash
ruby marketplace_monitor.rb run >> marketplace_monitor.log 2>&1
```

### System Log (Linux/Mac)

With cron logging:

```bash
0 */2 * * * cd /path/to/app && ruby marketplace_monitor.rb run >> /var/log/marketplace_monitor.log 2>&1
```

View logs:

```bash
tail -f /var/log/marketplace_monitor.log
```

### Running in Background

```bash
# Run as daemon in background
nohup ruby marketplace_monitor.rb daemon > marketplace_monitor.log 2>&1 &

# Get process ID
ps aux | grep marketplace_monitor.rb

# Stop the daemon
kill <process_id>
```

### Docker Deployment

Create a `Dockerfile`:

```dockerfile
FROM ruby:3.2-slim

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["ruby", "marketplace_monitor.rb", "daemon"]
```

Build and run:

```bash
docker build -t marketplace-monitor .
docker run -d --env-file .env -v $(pwd)/data:/app/data marketplace-monitor
```

## API Costs

- **Cost**: 1 credit per API request
- **Billing**: Credit-based system; pay for what you use
- **Example**: Searching 4 times daily × 2 search queries = 8 credits/day ≈ $0.04/day

## Architecture

```
marketplace_monitor.rb
├── Config              - Environment variable management
├── Database            - SQLite operations
├── MarketplaceAPI      - SociaVault API wrapper
├── EmailService        - SMTP email sending
└── MarketplaceMonitor  - Main orchestration logic
```

## Error Handling

The app gracefully handles:
- Network timeouts
- Invalid API responses
- Missing email configuration
- Database errors
- Duplicate listing prevention

Errors are logged to console and don't crash the daemon.

## Security Notes

- Store `.env` file securely; don't commit to version control
- Use app-specific passwords for email (not your actual password)
- Restrict database file permissions: `chmod 600 marketplace_monitor.db`
- For production, consider using a secret manager (AWS Secrets, HashiCorp Vault, etc.)

## Extending the App

### Custom Alerts

Modify `EmailService.build_html_email()` to customize email templates.

### Additional Integrations

Add new notification methods:
- Slack notifications
- SMS alerts (Twilio)
- Discord webhooks
- Webhook POST to your server

### Database Queries

Access the SQLite database directly for analysis:

```bash
sqlite3 marketplace_monitor.db

# View recent listings
SELECT title, price, location, first_seen_at FROM listings ORDER BY first_seen_at DESC LIMIT 10;

# Count listings by search query
SELECT search_query, COUNT(*) FROM listings GROUP BY search_query;
```

## Performance

- Typical API response: < 1 second
- Email sending: < 2 seconds per recipient
- Database operations: < 100ms
- Full cycle (4 searches, 2 emails): ~5 seconds
- Low CPU/memory footprint (~20MB resident)

## License

MIT

## Support

- SociaVault Docs: https://docs.sociavault.com
- SociaVault Support: support@sociavault.com
- Discord: https://discord.gg/sociavault

## Changelog

### v1.0.0

- Initial release
- Multi-search support
- Email alerts
- SQLite tracking
- Cron scheduling
- Gmail, SendGrid, AWS SES support

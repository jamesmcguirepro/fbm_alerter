# Cron Scheduling Setup Guide

This guide explains how to schedule the marketplace monitor to run automatically using cron.

## Why Use Cron?

- Runs automatically without keeping a terminal open
- More reliable than manual runs
- Survives server restarts
- Can run at specific times
- Minimal system resources

## Quick Start

### 1. Find Your App Path

```bash
pwd
# Output: /home/username/marketplace_monitor
```

Remember this path—you'll need it for the cron command.

### 2. Edit Your Crontab

```bash
crontab -e
```

This opens your cron editor (usually nano or vim).

### 3. Add a Cron Job

Here are common scheduling patterns. Pick one and add it to your crontab:

#### Every 30 Minutes

```bash
*/30 * * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Every Hour

```bash
0 * * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Every 2 Hours

```bash
0 */2 * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Every 6 Hours

```bash
0 */6 * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Every Day at 9 AM

```bash
0 9 * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Multiple Times Daily (6 AM, 12 PM, 6 PM, 12 AM)

```bash
0 6,12,18,0 * * * cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

#### Every Weekday at 8 AM and 5 PM (Mon-Fri)

```bash
0 8,17 * * 1-5 cd /home/username/marketplace_monitor && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

### 4. Save and Exit

- **Nano**: Press `Ctrl+X`, then `Y` to confirm, then `Enter`
- **Vim**: Press `Esc`, type `:wq`, then `Enter`

### 5. Verify Installation

Check that your cron job was added:

```bash
crontab -l
```

You should see your command listed.

## Understanding Cron Syntax

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday; 7 is also Sunday)
│ │ │ │ │
│ │ │ │ │
* * * * * command to run
```

## Examples Explained

### `*/30 * * * *`

- `*/30` = Every 30 minutes
- `*` = Every hour
- `*` = Every day of month
- `*` = Every month
- `*` = Every day of week

Result: **Runs every 30 minutes, 24/7**

### `0 9 * * *`

- `0` = Minute 0 (top of the hour)
- `9` = 9 AM
- `*` = Every day of month
- `*` = Every month
- `*` = Every day of week

Result: **Runs daily at 9:00 AM**

### `0 */6 * * *`

- `0` = Minute 0
- `*/6` = Every 6 hours (0, 6, 12, 18)
- Rest = Every day

Result: **Runs at 12 AM, 6 AM, 12 PM, 6 PM**

### `0 8,17 * * 1-5`

- `0` = Minute 0
- `8,17` = 8 AM and 5 PM
- `*` = Every day of month
- `*` = Every month
- `1-5` = Monday through Friday

Result: **Runs at 8 AM and 5 PM on weekdays**

## Logging

The command includes logging:

```bash
>> /var/log/marketplace_monitor.log 2>&1
```

This appends output to a log file. To view logs:

```bash
tail -f /var/log/marketplace_monitor.log
```

Or for the last 50 lines:

```bash
tail -50 /var/log/marketplace_monitor.log
```

## Troubleshooting

### Cron Job Not Running

1. **Verify it's scheduled:**
   ```bash
   crontab -l
   ```

2. **Check logs:**
   ```bash
   tail -f /var/log/marketplace_monitor.log
   ```

3. **Check system cron logs:**
   ```bash
   # macOS
   log stream --predicate 'process == "cron"' --level debug

   # Linux (systemd)
   journalctl -u cron

   # Linux (other)
   tail -f /var/log/syslog | grep CRON
   ```

4. **Check permissions:**
   ```bash
   ls -la main.rb
   chmod +x main.rb
   ```

### Command Not Found Error

- Specify full path to ruby:
  ```bash
  /usr/bin/ruby /home/username/marketplace_monitor/main.rb run
  ```

- Find ruby path:
  ```bash
  which ruby
  ```

### Permission Denied Error

Make sure the script is executable:

```bash
chmod +x main.rb
```

### Environment Variables Not Loaded

If your `.env` isn't being read, explicitly source it:

```bash
*/30 * * * * cd /home/username/marketplace_monitor && export $(cat .env | xargs) && ruby main.rb run >> /var/log/marketplace_monitor.log 2>&1
```

Or use a wrapper script:

Create `run.sh`:
```bash
#!/bin/bash
cd /home/username/marketplace_monitor
source .env
ruby main.rb run
```

Then in crontab:
```bash
*/30 * * * * /home/username/marketplace_monitor/run.sh >> /var/log/marketplace_monitor.log 2>&1
```

### "Insufficient credits" Errors

You're being charged for each search. Check your SociaVault credit balance and add credits if needed.

### Emails Not Sending via Cron

Cron runs in a minimal environment. Ensure:

1. All environment variables are in `.env`
2. SMTP credentials are correct
3. Full paths are used
4. No interactive prompts

## Recommended Schedules

**For Frequent Purchases:**
- Every 30 minutes: `*/30 * * * *`
- Best for: Time-sensitive items (cars, electronics, deals)

**For Regular Browsing:**
- Every 2 hours: `0 */2 * * *`
- Best for: General categories

**For Daily Digest:**
- Once daily: `0 9 * * *`
- Best for: Less time-sensitive categories

**For Business Hours Only:**
- 9 AM to 5 PM: `0 9-17 * * *`
- Best for: Business purchases, limited budget

## Advanced: Multiple Searches on Different Schedules

Create separate cron jobs for different searches by creating wrapper scripts:

`monitor_cars.sh`:
```bash
#!/bin/bash
cd /path/to/app
export $(cat .env | xargs)
ruby main.rb run  # This uses SEARCHES from .env
```

Then:
```bash
0 */1 * * * /path/to/app/monitor_cars.sh
```

Or modify the app to support different .env files:
```bash
SEARCHES_FILE=.env.cars ruby main.rb run
```

## Testing Your Cron Setup

### Dry Run

Run the command manually to verify it works:

```bash
cd /home/username/marketplace_monitor && ruby main.rb run
```

### Run with Cron Environment

Simulate cron's minimal environment:

```bash
env -i HOME=$HOME /bin/sh -c 'cd /home/username/marketplace_monitor && ruby main.rb run'
```

### Check Cron Daemon

Ensure cron is running:

```bash
# macOS
launchctl list | grep cron

# Linux
systemctl status cron
systemctl status crond  # Some systems use crond instead
```

## Stopping a Cron Job

Edit crontab and comment out or delete the line:

```bash
crontab -e
# Comment out:
# */30 * * * * cd /home/username/marketplace_monitor && ruby main.rb run
```

Save and exit.

## Moving to a Server

If running on a server:

1. **SSH into your server:**
   ```bash
   ssh user@server.com
   ```

2. **Clone the app:**
   ```bash
   git clone <repo> ~/marketplace_monitor
   cd ~/marketplace_monitor
   ```

3. **Set up:**
   ```bash
   bash setup.sh
   ```

4. **Add to crontab:**
   ```bash
   crontab -e
   # Add your cron job
   ```

5. **Check it's running:**
   ```bash
   tail -f /var/log/marketplace_monitor.log
   ```

## Resources

- [Crontab.guru](https://crontab.guru/) - Interactive cron schedule builder
- [Linux Cron Manual](https://linux.die.net/man/5/crontab)
- [macOS launchd](https://www.launchd.info/) - Alternative to cron

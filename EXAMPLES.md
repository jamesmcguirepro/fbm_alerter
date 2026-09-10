# Configuration Examples

Real-world examples for different use cases.

## Example 1: Used Cars - Multi-City Search

Monitor used cars for $5,000-$15,000 across multiple cities with shipping options.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=car-alerts@example.com
EMAIL_TO=you@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=2h

# Austin, Dallas, Houston
SEARCHES=used car|30.2672|-97.7431|5000|15000|100;car|32.7767|-96.7970|5000|15000|100;car|29.7604|-95.3698|5000|15000|100
```

## Example 2: Home Furniture - Local Pickup Only

Monitor furniture for local pickup within 10km at various price points.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=furniture-alerts@example.com
EMAIL_TO=you@example.com,roommate@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=1h

# Couch, Chair, Desk - New York City
SEARCHES=couch|40.7128|-74.0060|100|800|10||local_pickup;chair|40.7128|-74.0060|50|400|10||local_pickup;desk|40.7128|-74.0060|100|600|10||local_pickup
```

## Example 3: Gaming Equipment - Condition Filters

Monitor gaming gear with specific condition filters.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=gaming-alerts@example.com
EMAIL_TO=gamer@example.com

SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=SG.xxxxxxxxxxxxxxxxxxxxx

SCHEDULE_INTERVAL=30m

# PS5, Xbox, Nintendo Switch - Good/Like-New condition
SEARCHES=PS5|37.7749|-122.4194|300|600|25|used_good;Xbox|37.7749|-122.4194|200|500|25|used_good;Nintendo Switch|37.7749|-122.4194|200|400|25|used_like_new
```

## Example 4: Musical Instruments - Regional Search

Monitor instruments for sale within a music-loving region.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=music-alerts@example.com
EMAIL_TO=musician@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=4h

# Guitar, Keyboard, Drums - Nashville, TN area
SEARCHES=guitar|36.1627|-86.7816|0|2000|50;keyboard|36.1627|-86.7816|50|1500|50;drums|36.1627|-86.7816|50|1500|50
```

## Example 5: Budget Shopping - Under $50

Monitor deals across categories, all under $50.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=deals@example.com
EMAIL_TO=deal-hunter@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=15m

# Electronics, clothes, books, toys - all under $50
SEARCHES=electronics|40.7128|-74.0060|0|50|15;clothing|40.7128|-74.0060|0|50|15;books|40.7128|-74.0060|0|50|15;toys|40.7128|-74.0060|0|50|15
```

## Example 6: Real Estate/Rental Search

Monitor rental properties and real estate listings.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=property-alerts@example.com
EMAIL_TO=you@example.com,partner@example.com,realtor@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=1h

# Apartment, house for rent/sale - Los Angeles area
SEARCHES=apartment|34.0522|-118.2437|1000|3000|25;house|34.0522|-118.2437|2000|5000|25
```

## Example 7: Business Resale - Shipping Worldwide

Monitor items with worldwide shipping available.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=resale-alerts@example.com
EMAIL_TO=reseller@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=30m

# Collectibles and vintage items - shipping available
SEARCHES=vintage|40.7128|-74.0060|0|500|500||shipping;collectibles|40.7128|-74.0060|0|1000|500||shipping;antique|40.7128|-74.0060|0|800|500||shipping
```

## Example 8: Sports Equipment - Regional Tournament Prep

Monitor sports gear before a tournament.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=sports-alerts@example.com
EMAIL_TO=coach@example.com,team@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=30m

# Soccer balls, cleats, shin guards - New condition
SEARCHES=soccer ball|41.8781|-87.6298|10|50|25|new;soccer cleats|41.8781|-87.6298|30|100|25|new;shin guards|41.8781|-87.6298|20|80|25|new
```

## Example 9: Work-From-Home Setup

Monitor office and tech equipment for home office setup.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=wfh-alerts@example.com
EMAIL_TO=work@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=2h

# Desk, chair, monitor, keyboard
SEARCHES=office desk|33.7490|-84.3880|50|400|20|used_good;office chair|33.7490|-84.3880|50|300|20|used_good;monitor|33.7490|-84.3880|50|300|20|used_good;keyboard|33.7490|-84.3880|20|150|20|used_like_new
```

## Example 10: Pet Supplies & Equipment

Monitor pet-related items and equipment.

```env
SOCIAVAULT_API_KEY=sk_live_your_key_here
EMAIL_FROM=pet-alerts@example.com
EMAIL_TO=pet-owner@example.com

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

SCHEDULE_INTERVAL=1h

# Dog crate, cat tree, pet bed, leash
SEARCHES=dog crate|47.6062|-122.3321|20|100|15;cat tree|47.6062|-122.3321|20|100|15;pet bed|47.6062|-122.3321|10|50|15;dog leash|47.6062|-122.3321|5|50|15
```

## Finding Coordinates for Your City

Use Google Maps or these tools:
- [LatLong.net](https://www.latlong.net/)
- [GPS Coordinates](https://www.gps-coordinates.net/)
- [OpenStreetMap](https://www.openstreetmap.org/)

**Google Maps method:**
1. Open Google Maps
2. Right-click on your desired location
3. Click the coordinates that appear at the top
4. They're copied to your clipboard

## Common Coordinates Reference

```
New York City:    40.7128, -74.0060
Los Angeles:      34.0522, -118.2437
Chicago:          41.8781, -87.6298
Houston:          29.7604, -95.3698
Phoenix:          33.4484, -112.0742
Philadelphia:     39.9526, -75.1652
San Antonio:      29.4241, -98.4936
San Diego:        32.7157, -117.1611
Dallas:           32.7767, -96.7970
San Jose:         37.3382, -121.8863
Austin:           30.2672, -97.7431
Seattle:          47.6062, -122.3321
Denver:           39.7392, -104.9903
Boston:           42.3601, -71.0589
Miami:            25.7617, -80.1918
San Francisco:    37.7749, -122.4194
Atlanta:          33.7490, -84.3880
Nashville:        36.1627, -86.7816
Portland:         45.5152, -122.6784
London, UK:       51.5074, -0.1278
Toronto:          43.6532, -79.3832
Toronto:          43.6532, -79.3832
Sydney:           -33.8688, 151.2093
Tokyo:            35.6762, 139.6503
```

## Condition Options

- `new` - Brand new, unopened
- `used_like_new` - Like new condition
- `used_good` - Good condition
- `used_fair` - Fair/acceptable condition

## Delivery Options

- `all` - All delivery methods
- `local_pickup` - Local pickup only
- `shipping` - Shipping available

## Setting Different Intervals

Adjust `SCHEDULE_INTERVAL` based on urgency:

- `15m` - Very frequent (high-traffic items)
- `30m` - Frequent (popular items)
- `1h` - Hourly (regular monitoring)
- `2h` - Twice daily
- `6h` - Daily
- `24h` - Weekly

## Email Recipients

Single recipient:
```env
EMAIL_TO=you@example.com
```

Multiple recipients:
```env
EMAIL_TO=you@example.com,friend@example.com,family@example.com
```

## Testing Your Configuration

Before deploying, test with a manual run:

```bash
# Verify .env is set correctly
cat .env

# Run once
ruby main.rb run

# Check logs
tail -50 marketplace_monitor.log

# Verify database
sqlite3 marketplace_monitor.db "SELECT COUNT(*) FROM listings;"
```

## Production Deployment Checklist

- [ ] API key working and has sufficient credits
- [ ] Email credentials verified (test with manual run)
- [ ] Searches returning results
- [ ] Email recipients confirmed
- [ ] Database initialized
- [ ] Cron job added or daemon configured
- [ ] Log file location accessible
- [ ] `.env` file secured (not in version control)
- [ ] Tested with manual run
- [ ] Verified email delivery

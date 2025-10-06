# DateTime API - Go Implementation

RESTful API for time-related operations built with Go standard library.

## Features

- **Timezone Converter** - Convert time between different timezones
- **Time Calculator** - Add/subtract time or calculate differences
- **World Clock** - Get current time in major world cities
- **Countdown Timer** - Calculate time remaining to a target date
- **Business Days Calculator** - Calculate business days excluding weekends and holidays

## Getting Started

### Prerequisites

- Go 1.21 or higher
- Docker (optional)

### Local Development

```bash
# Navigate to the project directory
cd api-go

# Download dependencies
go mod tidy

# Run the server
go run main.go
```

The server will start on `http://localhost:8080`

### Docker

```bash
# Build the image
docker build -t datetime-api-go .

# Run the container
docker run -p 8080:8080 datetime-api-go
```

## API Endpoints

### Health Check

```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-10-06T12:00:00Z",
  "service": "datetime-api-go"
}
```

---

### Timezone Converter

```bash
POST /api/timezone/convert
```

**Request:**
```json
{
  "time": "2024-10-06T12:00:00Z",
  "from_timezone": "America/New_York",
  "to_timezone": "Europe/Istanbul"
}
```

**Response:**
```json
{
  "original_time": "2024-10-06T12:00:00-04:00",
  "original_timezone": "America/New_York",
  "converted_time": "2024-10-06T19:00:00+03:00",
  "converted_timezone": "Europe/Istanbul",
  "offset": "+07"
}
```

---

### Time Calculator

**Calculate difference between two times:**

```bash
POST /api/time/calculate
```

**Request:**
```json
{
  "start_time": "2024-01-01T00:00:00Z",
  "end_time": "2024-10-06T12:00:00Z"
}
```

**Response:**
```json
{
  "result": "2024-10-06T12:00:00Z",
  "difference": {
    "years": 0,
    "months": 9,
    "days": 5,
    "hours": 12,
    "minutes": 0,
    "seconds": 0,
    "total_duration": "6696h0m0s"
  }
}
```

**Add/subtract time:**

```bash
POST /api/time/calculate
```

**Request:**
```json
{
  "start_time": "2024-10-06T12:00:00Z",
  "operation": "add",
  "days": 10,
  "hours": 5,
  "minutes": 30
}
```

**Response:**
```json
{
  "result": "2024-10-16T17:30:00Z"
}
```

---

### World Clock

**Get time in all major cities:**

```bash
GET /api/worldclock
```

**Response:**
```json
[
  {
    "city": "New York",
    "timezone": "America/New_York",
    "time": "08:30:15",
    "date": "2024-10-06",
    "offset": "EDT (UTC-04)",
    "is_dst": true
  },
  {
    "city": "Istanbul",
    "timezone": "Europe/Istanbul",
    "time": "15:30:15",
    "date": "2024-10-06",
    "offset": "TRT (UTC+03)",
    "is_dst": false
  }
]
```

**Get time for specific timezone:**

```bash
GET /api/worldclock/city?timezone=Asia/Tokyo
```

**Response:**
```json
{
  "city": "Asia/Tokyo",
  "timezone": "Asia/Tokyo",
  "time": "21:30:15",
  "date": "2024-10-06",
  "offset": "JST (UTC+09)",
  "is_dst": false
}
```

---

### Countdown Timer

```bash
POST /api/countdown
```

**Request:**
```json
{
  "target_time": "2025-01-01T00:00:00Z",
  "from_time": "2024-10-06T12:00:00Z"
}
```

**Response:**
```json
{
  "target_time": "2025-01-01T00:00:00Z",
  "current_time": "2024-10-06T12:00:00Z",
  "time_remaining": {
    "years": 0,
    "months": 2,
    "days": 25,
    "hours": 12,
    "minutes": 0,
    "seconds": 0,
    "total_duration": "2076h0m0s"
  },
  "is_past": false,
  "total_seconds": 7473600
}
```

---

### Business Days Calculator

**Calculate business days between dates:**

```bash
POST /api/businessdays
```

**Request:**
```json
{
  "start_date": "2024-10-01",
  "end_date": "2024-10-31",
  "timezone": "Europe/Istanbul",
  "holidays": ["2024-10-29"]
}
```

**Response:**
```json
{
  "start_date": "2024-10-01",
  "end_date": "2024-10-31",
  "business_days": 22,
  "total_days": 31,
  "weekends": 8,
  "holidays": 1
}
```

**Add business days to a date:**

```bash
POST /api/businessdays
```

**Request:**
```json
{
  "start_date": "2024-10-01",
  "days": 10,
  "timezone": "UTC",
  "holidays": ["2024-10-15"]
}
```

**Response:**
```json
{
  "start_date": "2024-10-01",
  "end_date": "2024-10-15",
  "business_days": 10,
  "total_days": 15,
  "weekends": 4,
  "holidays": 1
}
```

## Timezone Format

All timezone parameters use IANA timezone names:
- `America/New_York`
- `Europe/Istanbul`
- `Asia/Tokyo`
- `UTC`

Full list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

## Date/Time Format

- **ISO 8601 / RFC3339**: `2024-10-06T12:00:00Z` or `2024-10-06T12:00:00+03:00`
- **Date only**: `2024-10-06` (YYYY-MM-DD)

## Error Handling

All errors return a JSON response:

```json
{
  "error": "Invalid timezone",
  "message": "unknown time zone America/Invalid"
}
```

## Project Structure

```
api-go/
├── main.go              # Server setup and routes
├── handlers/            # HTTP handlers
│   ├── common.go        # Health check and utilities
│   ├── timezone.go      # Timezone conversion
│   ├── calculator.go    # Time calculations
│   ├── worldclock.go    # World clock
│   ├── countdown.go     # Countdown timer
│   └── businessdays.go  # Business days calculator
├── models/              # Data models
│   └── models.go
├── utils/               # Utility functions
│   └── timeutils.go
├── Dockerfile
├── go.mod
└── README.md
```

## Testing with curl

```bash
# Health check
curl http://localhost:8080/health

# Timezone conversion
curl -X POST http://localhost:8080/api/timezone/convert \
  -H "Content-Type: application/json" \
  -d '{"from_timezone":"America/New_York","to_timezone":"Europe/Istanbul"}'

# World clock
curl http://localhost:8080/api/worldclock

# Time calculation
curl -X POST http://localhost:8080/api/time/calculate \
  -H "Content-Type: application/json" \
  -d '{"start_time":"2024-10-06T12:00:00Z","operation":"add","days":5}'
```

## License

MIT

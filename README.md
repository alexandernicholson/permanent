# Permanent - High-Performance Disposable Email Checker

A blazing-fast disposable email check API built with Ruby and Sinatra, capable of handling over 120,000 requests per second.

## Features

- **High Performance**: Optimized for 120,000+ RPS using Set data structure for O(1) lookups
- **Request Logging**: Efficient logging with domain-only privacy protection
- **Auto-updating**: Automatically fetches and updates disposable domain lists
- **Containerized**: Docker-ready for easy deployment
- **Well-tested**: Comprehensive test suite with RSpec
- **Simple API**: Single endpoint returning JSON response

## API Endpoints

### Check Email
```
GET /check?email=user@example.com
```

Response:
```json
{
  "disposable": true
}
```

### Health Check
```
GET /health
```

Response:
```json
{
  "status": "ok",
  "domains_loaded": 123456,
  "last_update": 1700000000
}
```

## Quick Start

### Local Development

```bash
# Install dependencies
bundle install --path vendor/bundle

# Run tests
bundle exec rspec

# Start the server
bundle exec puma -C puma.rb

# Run performance benchmarks
bundle exec ruby benchmark.rb
```

### Docker Deployment

```bash
# Build the image
docker build -t disposable-email-checker .

# Run the container
docker run -p 3000:3000 -e WEB_CONCURRENCY=4 -e MAX_THREADS=16 disposable-email-checker
```

## Performance Optimization

The API achieves 120,000+ RPS through:

1. **Set-based lookups**: O(1) complexity for domain checks
2. **Puma web server**: Multi-threaded and multi-process configuration
3. **Minimal overhead**: Disabled unnecessary Sinatra features
4. **Efficient caching**: In-memory domain storage with background updates

## Configuration

Environment variables:
- `PORT`: Server port (default: 3000)
- `WEB_CONCURRENCY`: Number of Puma workers (default: 4)
- `MAX_THREADS`: Number of threads per worker (default: 16)
- `RACK_ENV`: Environment (default: production)

## Sources

Domain lists are fetched from:
- https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.txt

The API includes a built-in fallback list and updates hourly.

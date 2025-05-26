# Permanent - High-Performance Disposable Email Checker

A blazing-fast disposable email check API built with Ruby and Rack, capable of handling over 90,000 requests per second with efficient async logging.

## Features

- **High Performance**: Optimized for 90,000+ RPS using Set data structure for O(1) lookups
- **Async Request Logging**: Non-blocking logging with queue-based implementation for minimal performance impact
- **Privacy-focused**: Logs only domains, not full email addresses
- **Minimal Dependencies**: Pure Rack application without Sinatra overhead
- **Containerized**: Docker-ready for easy deployment
- **Well-tested**: Comprehensive test suite with RSpec
- **Simple API**: Clean JSON API with two endpoints

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

The API achieves 90,000+ RPS through:

1. **Set-based lookups**: O(1) complexity for domain checks
2. **Pure Rack application**: No framework overhead
3. **Async logging**: Queue-based logging in separate thread
4. **Pre-serialized responses**: Common JSON responses are cached
5. **Puma web server**: Multi-threaded and multi-process configuration
6. **Efficient memory usage**: In-memory domain storage with minimal allocations

### Performance & Logging

The API includes high-performance async logging that records all requests with minimal overhead. However, logging may still have an impact on performance (at a maximum of around 10%).

To disable logging for maximum performance:
```bash
DISABLE_LOGGING=true bundle exec puma -C puma.rb
```

The async logging system uses batch processing and a background thread to minimize impact on request handling while providing valuable request tracking, so we highly recommend you enable it.

## Configuration

Environment variables:
- `PORT`: Server port (default: 3000)
- `WEB_CONCURRENCY`: Number of Puma workers (default: 4)
- `MAX_THREADS`: Number of threads per worker (default: 16)
- `RACK_ENV`: Environment (default: production)
- `DISABLE_LOGGING`: Set to 'true' to disable request logging for maximum performance

## Sources

Domain lists are fetched from:
- https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.txt

The API loads domains from a local file at startup for maximum performance.

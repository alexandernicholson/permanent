# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby-based disposable email check API that determines whether an email domain is from a temporary/disposable email service. The API automatically updates its domain list on startup from external sources, with a built-in default list as fallback.

## Architecture

- **app.rb**: Main application file with high-performance Sinatra API using Set data structure for O(1) lookups
- **config.ru**: Rack configuration for the application
- **puma.rb**: Puma web server configuration optimized for high concurrency
- **sources/disposable-email-domains/domains.txt**: Local cache of disposable email domains
- The API fetches domain lists from: https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.txt

## API Endpoints

- `GET /check?email=user@example.com` - Returns `{"disposable": true/false}`
- `GET /health` - Returns health status with domain count and last update time

## Development Commands

- `bundle install` - Install dependencies
- `bundle exec rspec` - Run tests
- `bundle exec puma -C puma.rb` - Run the application with Puma
- `bundle exec ruby benchmark.rb` - Run performance benchmarks
- `docker build -t disposable-email-checker .` - Build Docker image
- `docker run -p 3000:3000 disposable-email-checker` - Run in Docker container

## Implementation Notes

The API should:
1. Load the domain list from sources/disposable-email-domains/domains.txt on startup
2. Attempt to update the list from the remote source
3. Provide a simple endpoint that returns a boolean indicating if an email domain is disposable
4. Handle cases where the remote source is unavailable by falling back to the local list
FROM ruby:3.2-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs 4 --retry 3

COPY . .

RUN mkdir -p sources/disposable-email-domains

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
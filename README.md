# Caffeine Monster

A Rails 7.1 application with MySQL, Redis, and Hotwire (Turbo + Stimulus).

## Requirements

- Ruby 3.1.3
- Docker & Docker Compose (recommended) **or** MySQL 8.0 + Redis installed locally

## Setup

### Option A — Docker (recommended)

1. Copy the example environment file and fill in your values:

   ```bash
   cp .env.example .env
   # Set RAILS_MASTER_KEY and REDIS_URL in .env
   ```

2. Start the services:

   ```bash
   docker compose up --build
   ```

3. In a separate terminal, set up the database:

   ```bash
   docker compose exec web bin/rails db:create db:migrate db:seed
   ```

The app will be available at `http://localhost:3000`.

### Option B — Local

1. Install dependencies:

   ```bash
   bundle install
   ```

2. Set environment variables (or export them in your shell):

   | Variable            | Default             | Description                     |
   |---------------------|---------------------|---------------------------------|
   | `DATABASE_NAME`     | `caffeine_monster`  | MySQL database name             |
   | `DATABASE_PASSWORD` | `root`              | MySQL root password             |
   | `DATABASE_HOST`     | `db`                | MySQL host (use `127.0.0.1` locally) |
   | `DATABASE_PORT`     | `3306`              | MySQL port                      |
   | `REDIS_URL`         | —                   | Redis connection URL            |
   | `RAILS_MASTER_KEY`  | —                   | Rails credentials master key    |

3. Create and migrate the database:

   ```bash
   bin/rails db:create db:migrate db:seed
   ```

4. Start the server:

   ```bash
   bin/rails server
   ```

## Running Tests

```bash
bundle exec rspec                              # full suite
bundle exec rspec spec/models/                 # models only
bundle exec rspec spec/path/to/file_spec.rb    # single file
bundle exec rspec spec/path/to/file_spec.rb:42 # single example
```

The test suite connects to a real MySQL database (`caffeine_monster_test` on host `db`, port `3306`). When running locally, set `DATABASE_HOST=127.0.0.1`.

## Linting

```bash
bundle exec rubocop              # check all files
bundle exec rubocop --autocorrect # auto-fix offences
```

RuboCop runs automatically on every push via GitHub Actions.

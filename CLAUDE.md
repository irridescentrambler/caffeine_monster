# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

Rails 7.1.2 on Ruby 3.1.3 with MySQL, Redis, Hotwire (Turbo + Stimulus), Importmap. No Devise — auth is hand-rolled with bcrypt + JWT.

## Common Commands

```bash
bin/rails server
bin/rails console
bin/rails db:migrate
bin/rails db:reset                          # drop + create + migrate + seed

bundle exec rspec                           # full suite
bundle exec rspec spec/models/              # models only
bundle exec rspec spec/path/to/file_spec.rb # single file
bundle exec rspec spec/path/to/file_spec.rb:42  # single example

bundle exec rubocop                         # lint all
bundle exec rubocop --autocorrect           # auto-fix
bundle exec rubocop path/to/file.rb         # single file

bin/rails routes --grep user                # search routes
```

## Code Conventions

- Every Ruby file starts with `# frozen_string_literal: true`
- Max method length: 20 lines (RuboCop enforced); `Metrics/BlockLength` is disabled
- Business logic lives in `app/services/` — keep controllers thin
- Use FactoryBot for test data; never use Rails fixtures
- Write RSpec tests only — ignore the `test/` directory (legacy, not used)
- `verify_partial_doubles: true` — all stubs must be on real methods
- Default pagination: 15 per page (set in `ApplicationRecord`)

## Architecture

### Dual Auth: Sessions (HTML) + JWT (API)

The `Authorize` concern (`app/controllers/concerns/authorize.rb`) handles both auth modes:

- **HTML requests**: Checks `session[:user_id]`, redirects to `/login` if missing
- **JSON requests**: Calls `AuthorizeUserService` which decodes a Bearer JWT from the Authorization header

`SessionsController` issues both: sets `session[:user_id]` for HTML logins, returns a JWT token for JSON logins. JWT encoding/decoding lives in `lib/json_web_token.rb` using `Rails.application.credentials.auth_secret_key`.

Controllers skip auth with `skip_before_action :authorize_request` for public actions (e.g., login, user creation).

### Service Layer Pattern

All services inherit from `BaseService` (`app/services/base_service.rb`):
- Provides a `Response` struct with `data`, `error`, and `success?`
- Class-level `.call(...)` instantiates and calls `#call`
- Services: `AuthenticateUserService` (login), `AuthorizeUserService` (JWT verification)

### Domain Model

- **User** has_secure_password; has_one :account (through AccountUser); has_many :teams (through Membership)
- **Account** tracks balance (decimal, >= 0); has `add_money`/`withdraw_money` with bang variants
- **Team** has_many :members (users) through Membership
- **Membership** join: belongs_to :member (class_name: 'User'), belongs_to :team
- **Category** validates name uniqueness scoped to parent_id (when active)

### Rate Limiting

Rack::Attack (`config/initializers/rack_attack.rb`): 100 requests per IP per minute. Returns 429 JSON on throttle.

### CI

GitHub Actions runs RuboCop on push (`.github/workflows/rubocop.yml`). Dependabot is configured for dependency updates.

## Test Setup

- Database cleaner: transaction strategy by default, truncation for JS tests (`spec/rails_helper.rb`)
- FactoryBot syntax methods included globally
- ActiveSupport::Testing::TimeHelpers included for time travel in tests

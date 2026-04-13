# Caffeine Monster

Rails 7.1.2 app on Ruby 3.1.3 with MySQL and Redis.

## Stack

- **Framework**: Rails 7.1.2, Hotwire (Turbo + Stimulus), Importmap
- **Auth**: Custom — bcrypt for passwords, JWT for web page auth (no Devise)
- **Database**: MySQL (mysql2 ~> 0.5.5)
- **Cache / Realtime**: Redis (Action Cable)
- **Pagination**: Kaminari
- **Rate Limiting**: Rack::Attack
- **Tests**: RSpec, FactoryBot, Capybara + Selenium WebDriver, database_cleaner-active_record
- **Linter**: RuboCop with rubocop-rails, rubocop-performance, rubocop-capybara plugins

## Common Commands

```bash
# Server
bin/rails server

# Console
bin/rails console

# Database
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:seed
bin/rails db:reset          # drop + create + migrate + seed

# Generators
bin/rails generate model Foo bar:string
bin/rails generate migration AddColumnToTable column:type
bin/rails generate rspec:model Foo

# Tests
bundle exec rspec                           # full suite
bundle exec rspec spec/models/              # models only
bundle exec rspec spec/path/to/file_spec.rb # single file
bundle exec rspec spec/path/to/file_spec.rb:42  # single example

# Linting
bundle exec rubocop                         # check all
bundle exec rubocop --autocorrect           # fix auto-correctable offenses
bundle exec rubocop path/to/file.rb         # single file

# Routes
bin/rails routes
bin/rails routes --grep user
```

## Code Conventions

- Every Ruby file starts with `# frozen_string_literal: true`
- Max method length: 20 lines (RuboCop enforced)
- `Metrics/BlockLength` is disabled (long blocks like RSpec describes are fine)
- Business logic lives in `app/services/` — keep controllers thin
- Use FactoryBot for test data; do not use Rails fixtures
- Write RSpec tests only — ignore the `test/` directory (legacy, not used)
- `verify_partial_doubles: true` is set in spec_helper — all stubs must be on real methods

## Architecture Notes

- **Services layer**: Extract complex business logic to `app/services/`
- **Auth flow**: Custom JWT issued at login, verified in `before_action` on authenticated pages
- **Rate limiting**: Rack::Attack configured — be mindful when writing endpoints that accept unauthenticated requests
- No Devise — session and authentication logic is hand-rolled

## Project Structure

```
app/
  controllers/    # Thin — delegate to services
  models/         # ActiveRecord models
  services/       # Business logic
  views/          # ERB templates with Turbo frames/streams
  javascript/     # Stimulus controllers
  jobs/           # ActiveJob background jobs
  mailers/
  channels/       # Action Cable channels
config/
  routes.rb
  initializers/
db/
  migrate/
  schema.rb
  seeds.rb
spec/             # All tests go here
  models/
  controllers/
  system/         # Capybara system tests
  factories/      # FactoryBot factories
  support/        # Shared helpers and config
```

## Testing Patterns

```ruby
# Model spec
RSpec.describe User, type: :model do
  subject { build(:user) }
  it { is_expected.to be_valid }
end

# Controller spec
RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user) }
  # ...
end

# System spec (Capybara)
RSpec.describe "Login", type: :system do
  it "allows a user to log in" do
    visit login_path
    # ...
  end
end
```

## Environment Variables

Uses standard Rails credentials or `.env`-style setup. Check `config/credentials.yml.enc` and environment-specific files for secrets (JWT secret key, database credentials, Redis URL, etc.).

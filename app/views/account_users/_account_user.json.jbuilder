# frozen_string_literal: true

json.extract! account_user, :id, :user_id, :account_id, :created_at, :updated_at
json.url account_user_url(account_user, format: :json)

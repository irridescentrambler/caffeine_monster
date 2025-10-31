# frozen_string_literal: true

json.extract! membership, :id, :member_id, :team_id, :created_at, :updated_at
json.url membership_url(membership, format: :json)

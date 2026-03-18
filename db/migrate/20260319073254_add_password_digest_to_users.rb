# frozen_string_literal: true

# Adds password_digest to users for secure password storage (has_secure_password).
class AddPasswordDigestToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :password_digest, :string, null: false # rubocop:disable Rails/NotNullColumn
  end
end

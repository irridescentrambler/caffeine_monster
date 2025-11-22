# frozen_string_literal: true

# Migration to add unique indexes to the users table.
#
# This migration adds unique indexes on the `id` and `email` columns
# of the users table to ensure data integrity and improve query performance
# when looking up users by these fields.
#
# Indexes added:
# - users.id: Unique index (enforces uniqueness at database level)
# - users.email: Unique index (prevents duplicate email addresses)
class AddIndexToUserIdAndEmail < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |t|
      t.index :id, unique: true
      t.index :email, unique: true
    end
  end
end

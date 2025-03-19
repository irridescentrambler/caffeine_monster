# frozen_string_literal: true

# Class Account deals with accounts table
class Account < ApplicationRecord
  has_many :account_users
  has_many :users, through: :account_users
end

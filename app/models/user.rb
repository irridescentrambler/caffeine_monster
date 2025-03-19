# frozen_string_literal: true

# Class User deals with users table
class User < ApplicationRecord
  has_one :account_user
  has_one :account, through: :account_user
end

# frozen_string_literal: true

# class AccountUser deals with mapping of accounts and users
class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user
end

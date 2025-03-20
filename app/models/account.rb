# frozen_string_literal: true

# Class Account deals with accounts table
class Account < ApplicationRecord
  has_many :account_users
  has_many :users, through: :account_users
  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  def add_money(amount)
    self.balance += amount
    Rails.logger.debug "Money #{amount} getting added to the account #{id}"
  end

  def add_money!(amount)
    add_money(amount)
    save
  end

  def withdraw_money(amount)
    self.balance -= amount
    Rails.logger.debug "Money #{amount} getting deducted from the account #{id}"
  end

  def withdraw_money!(amount)
    withdraw_money(amount)
    save
  end
end

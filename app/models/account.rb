# frozen_string_literal: true

# Class Account deals with accounts table
class Account < ApplicationRecord
  has_many :account_users
  has_many :users, through: :account_users

  def add_money(amount)
    self.balance += amount
  end

  def add_money!(amount)
    add_money(amount)
    save
  end

  def withdraw_money(amount)
    self.balance -= amount
  end

  def withdraw_money!(amount)
    withdraw_money(amount)
    save
  end
end

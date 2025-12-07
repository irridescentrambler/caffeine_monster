# frozen_string_literal: true

# Class User deals with users table
class User < ApplicationRecord
  has_one :account_user, dependent: :destroy
  has_one :account, through: :account_user
  has_many :memberships, foreign_key: :member_id, dependent: :destroy, inverse_of: :member
  has_many :teams, through: :memberships

  validates :email, uniqueness: { case_sensitive: true }
end

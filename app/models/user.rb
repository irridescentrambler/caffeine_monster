# frozen_string_literal: true

# Class User deals with users table
class User < ApplicationRecord
  has_one :account_user
  has_one :account, through: :account_user
  has_many :memberships, foreign_key: :member_id
  has_and_belongs_to_many :teams, join_table: :memberships, foreign_key: :member_id

  validates :email, uniqueness: true
  track_for_overfetching
end

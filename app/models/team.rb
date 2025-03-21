# frozen_string_literal: true

# Deals with teams table
class Team < ApplicationRecord
  has_many :memberships
  has_many :members, through: :memberships
end

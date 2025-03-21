# frozen_string_literal: true

# Deals with memberships table
class Membership < ApplicationRecord
  has_and_belongs_to_many :members, class_name: 'User'
  has_and_belongs_to_many :teams
end

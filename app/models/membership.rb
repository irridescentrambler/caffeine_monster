# frozen_string_literal: true

# Deals with memberships table
class Membership < ApplicationRecord
  belongs_to :member, class_name: 'User'
  belongs_to :team
end

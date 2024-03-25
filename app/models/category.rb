# frozen_string_literal: true

# Category model interacts with categories class
class Category < ApplicationRecord
  validates_uniqueness_of :name, scope: %i[parent_id], if: :active
end

# frozen_string_literal: true

# Category model interacts with categories class
class Category < ApplicationRecord
  validates :name, uniqueness: { scope: %i[parent_id], if: :active }
end

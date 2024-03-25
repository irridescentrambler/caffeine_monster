# frozen_string_literal: true

# Adds active column to categories
class AddActiveToCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :active, :boolean
  end
end

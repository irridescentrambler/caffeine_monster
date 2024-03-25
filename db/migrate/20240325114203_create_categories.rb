# frozen_string_literal: true

# Creates categories table
class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.integer :parent_id
      t.string :name
      t.timestamps
    end
  end
end

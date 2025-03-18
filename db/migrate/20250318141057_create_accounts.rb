class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.decimal :balance

      t.timestamps
    end
  end
end

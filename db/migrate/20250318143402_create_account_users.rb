class CreateAccountUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :account_users do |t|
      t.integer :user_id
      t.integer :account_id

      t.timestamps
    end
  end
end

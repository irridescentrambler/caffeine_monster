class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      t.integer :member_id
      t.integer :team_id

      t.timestamps
    end
  end
end

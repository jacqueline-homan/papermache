class CreateAccounts < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.references :student, index: true, foreign_key: true
      t.string :first_name
      t.string :last_name

      t.timestamps null: false
    end
  end
end

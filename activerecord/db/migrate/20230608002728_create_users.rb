class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: :string do |t|
      t.string :a_string
      t.integer :a_number
      t.boolean :a_bool

      t.timestamps
    end
  end
end

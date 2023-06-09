class CreateResources < ActiveRecord::Migration[7.0]
  def change
    create_table :resources, id: :string do |t|
      t.string :a_string
      t.integer :a_number
      t.boolean :a_bool
      t.references :creator, foreign_key: { to_table: :users }, type: :string

      t.timestamps
    end
  end
end

class CreateUserDetails < ActiveRecord::Migration[7.0]
  def change
    create_table :user_details, id: :string do |t|
      t.string :a_string
      t.belongs_to :user, type: :string

      t.timestamps
    end
  end
end

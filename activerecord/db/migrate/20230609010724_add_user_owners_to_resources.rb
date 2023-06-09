class AddUserOwnersToResources < ActiveRecord::Migration[7.0]
  def change
    create_table :resources_users, id: false do |t|
      t.belongs_to :user, type: :string
      t.belongs_to :resource, type: :string
    end
  end
end

class User < ApplicationRecord
  has_and_belongs_to_many :resources
  has_one :user_detail
end

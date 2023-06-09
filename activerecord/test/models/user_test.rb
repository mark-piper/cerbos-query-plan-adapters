require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    Fixtures::Cerbos.setup!
  end

  test "fixture" do
    assert_equal ["user1", "user2"], User.all.pluck(:id)
  end
end

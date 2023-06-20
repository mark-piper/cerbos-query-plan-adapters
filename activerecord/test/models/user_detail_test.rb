require "test_helper"

class UserDetailTest < ActiveSupport::TestCase
  setup do
    Fixtures::Cerbos.setup!
  end

  test "fixture" do
    assert_equal ["detail1", "detail2"], [User.first.user_detail.a_string, User.second.user_detail.a_string]
  end
end

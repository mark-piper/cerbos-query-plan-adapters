require "test_helper"

class UserDetailTest < ActiveSupport::TestCase
  setup do
    Fixtures::Cerbos.setup!
  end

  test "fixture" do
    assert_equal ["detail1", "detail2"], UserDetail.all.pluck(:id)
  end
end

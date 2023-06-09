require "test_helper"

class ResourceTest < ActiveSupport::TestCase
  setup do
    Fixtures::Cerbos.setup!
  end

  test "fixture" do
    assert_equal ["resource1", "resource2", "resource3"], Resource.all.pluck(:id)
    assert_equal "user1", Resource.all.first.creator.id
    assert_equal ["user2"], Resource.find("resource2").users.pluck(:id)
  end
end

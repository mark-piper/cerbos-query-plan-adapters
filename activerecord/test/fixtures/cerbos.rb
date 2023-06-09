module Fixtures
  # Test data matching the suite for @cerbos/orm-prisma
  # https://github.com/cerbos/query-plan-adapters/blob/main/prisma/src/index.test.ts
  class Cerbos
    def self.setup!
      user1 = User.create!(
        id: "user1",
        a_string: "string",
        a_number: 1,
        a_bool: true)

      user2 = User.create!(
        id: "user2",
        a_string: "string",
        a_number: 2,
        a_bool: true)

      Resource.create!(
        id: "resource1",
        a_bool: true,
        a_number: 1,
        a_string: "string",
        creator: user1,
        users: [user1]
      )

      Resource.create!(
        id: "resource2",
        a_bool: false,
        a_number: 2,
        a_string: "string2",
        creator: user2,
        users: [user2]
      )

      Resource.create!(
        id: "resource3",
        a_bool: false,
        a_number: 3,
        a_string: "string3",
        creator: user1,
        users: [user1, user2]
      )
    end
  end
end

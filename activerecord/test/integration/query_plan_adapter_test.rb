require "test_helper"
require "cerbos/query_plan_adapter"

class QueryPlanAdapterTest < ActiveSupport::TestCase

  # To start cerbos:
  #    cerbos server --log-level=error --set=storage.disk.directory=../policies --set=telemetry.disabled=true
  def cerbos
    Cerbos::Client.new("localhost:3593", tls: false)
  end

  setup do
    Fixtures::Cerbos.setup!
  end

  test "cerbos connection" do
    decision = cerbos.check_resource(
      principal: { id: 'user1', roles: ['USER'] },
      resource: { kind: "resource", id: 'new' }, actions: ['always-allow']
    )

    assert_equal decision.allow?('always-allow'), true
  end

  test "always allowed" do
    query_plan = cerbos.plan_resources(
        principal: { id: "user1", roles: ["USER"] },
        resource: { kind: "resource" },
        action: "always-allow"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource)
    relation = adapter.to_query

    assert_equal Resource.all.to_sql, relation.to_sql
  end

  test "always denied" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "always-deny"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource)
    relation = adapter.to_query

    assert_equal Resource.none.to_sql, relation.to_sql
  end

  test "conditional - eq" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "equal"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      'request.resource.attr.aBool' => :a_bool
    })

    expected = Resource.where(a_bool: true)
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - eq - inverted order" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "equal"
    )
    query_plan.condition.operands.reverse!

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      'request.resource.attr.aBool' => :a_bool
    })

    expected = Resource.where(a_bool: true)
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - ne" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "ne"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aString" => :a_string
    })

    expected = Resource.where.not(a_string: 'string')
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "condtional - explicit-deny" do
    # EFFECT_DENY if request.resource.attr.aBool == true
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "explicit-deny"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      'request.resource.attr.aBool' => :a_bool
    })

    expected = Resource.where.not(a_bool: true)
    actual = adapter.to_query
    assert_equal 'SELECT "resources".* FROM "resources" WHERE NOT ("resources"."a_bool" = 1)', actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - and" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "and"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aBool" => :a_bool,
      "request.resource.attr.aString" => :a_string
    })

    expected = Resource.where(a_bool: true).where.not(a_string: 'string')
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - or" do
    query_plan = cerbos.plan_resources(
    principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "or")

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aBool" => :a_bool,
    "request.resource.attr.aString" => :a_string
    })

    expected = Resource.where(a_bool: true).or(Resource.where.not(a_string: 'string'))
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - in" do
    query_plan = cerbos.plan_resources(
    principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "in"
    )
    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
    "request.resource.attr.aString" => :a_string
    })

    expected = Resource.where(a_string: ['string', 'anotherString'])
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - gt" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "gt"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aNumber" => :a_number
    })

    actual = adapter.to_query
    expected = Resource.where("a_number > ?", 1)
    assert_equal 'SELECT "resources".* FROM "resources" WHERE "resources"."a_number" > 1', actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - lt" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "lt"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aNumber" => :a_number
    })

    actual = adapter.to_query
    expected = Resource.where("a_number < ?", 2)
    assert_equal 'SELECT "resources".* FROM "resources" WHERE "resources"."a_number" < 2', actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - gte" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "gte"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aNumber" => :a_number
    })

    actual = adapter.to_query
    expected = Resource.where("a_number >= ?", 1)
    assert_equal 'SELECT "resources".* FROM "resources" WHERE "resources"."a_number" >= 1', actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - lte" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "lte"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.aNumber" => :a_number
    })

    actual = adapter.to_query
    expected = Resource.where("a_number <= ?", 2)
    assert_equal 'SELECT "resources".* FROM "resources" WHERE "resources"."a_number" <= 2', actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - relation some" do
    # EFFECT_ALLOW if P.id in request.resource.attr.ownedBy
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "relation-some"
    )

    adapter = Cerbos::QueryPlanAdapter.new(
      plan_resources: query_plan, model: Resource, field_mapping: {}, relationship_mapping: {
        "request.resource.attr.ownedBy" => {
          relation: "users",
          field: :id
      }
    })

    actual = adapter.to_query
    expected = Resource.joins(:users).where(users: { id: "user1" })
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - relation none" do
    # EFFECT_ALLOW if !(P.id in request.resource.attr.ownedBy)
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "relation-none"
    )

    adapter = Cerbos::QueryPlanAdapter.new(
      plan_resources: query_plan, model: Resource, field_mapping: {}, relationship_mapping: {
      "request.resource.attr.ownedBy" => {
        relation: "users",
        field: :id
      }
    })

    actual = adapter.to_query
    expected = Resource.where.not(id: Resource.joins(:users).where(users: { id: "user1"}))
    assert_equal expected.to_sql, actual.to_sql
    assert_equal ['resource2'], actual.pluck(:id).sort
  end

  test "conditional - relation is" do
      # EFFECT_ALLOW if request.resource.attr.createdBy == P.id
      query_plan = cerbos.plan_resources(
        principal: { id: "user1", roles: ["USER"] },
        resource: { kind: "resource" },
        action: "relation-is"
      )

      adapter = Cerbos::QueryPlanAdapter.new(
        plan_resources: query_plan, model: Resource, field_mapping: {}, logger: Logger.new(STDOUT),
        relationship_mapping: {
          "request.resource.attr.createdBy" => {
            relation: "creator",
            field: :id
          }
      })

      expected = Resource.joins(:creator).where(creator: { id: 'user1' })
      actual = adapter.to_query
      assert_equal expected.to_sql, actual.to_sql
      assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

  test "conditional - relation is field" do
    # EFFECT_ALLOW if request.resource.attr.createdBy == P.id
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "relation-is"
    )

    adapter = Cerbos::QueryPlanAdapter.new(plan_resources: query_plan, model: Resource, field_mapping: {
      "request.resource.attr.createdBy" => :creator_id
    })

    expected = Resource.where(creator_id: 'user1')
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal ['resource1', 'resource3'], actual.pluck(:id).sort
  end

  test "conditional - relation is not" do
    query_plan = cerbos.plan_resources(
      principal: { id: "user1", roles: ["USER"] },
      resource: { kind: "resource" },
      action: "relation-is-not"
    )

    adapter = Cerbos::QueryPlanAdapter.new(
      plan_resources: query_plan, model: Resource, field_mapping: {}, relationship_mapping: {
      "request.resource.attr.createdBy" => {
        "relation": "creator",
        "field": "id"
      }
    })

    expected = Resource.where.not(id: Resource.joins(:creator).where(creator: { id: 'user1'}))
    actual = adapter.to_query
    assert_equal expected.to_sql, actual.to_sql
    assert_equal expected.pluck(:id).sort, actual.pluck(:id).sort
  end

end
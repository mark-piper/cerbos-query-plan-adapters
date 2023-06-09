module Cerbos
  class QueryPlanAdapter
    attr_accessor :plan_resources, :model, :field_mapping, :relationship_mapping, :logger

    OPERATOR_MAP = { # c: column, v: value
        "eq" => ->(c, v, model) { model.arel_table[c].eq(v) },
        "ne" => ->(c, v, model) { model.arel_table[c].not_eq(v) },
        "in" => ->(c, v, model) { model.arel_table[c].in(v) },
        "gt" => ->(c, v, model) { model.arel_table[c].gt(v) },
        "lt" => ->(c, v, model) { model.arel_table[c].lt(v) },
        "ge" => ->(c, v, model) { model.arel_table[c].gteq(v) },
        "le" => ->(c, v, model) { model.arel_table[c].lteq(v) },
    }.freeze

    # Initialize an adapter to convert a Cerbos query plan (from a `plan_resources` call) into
    # an ActiveRecord query.
    # TODO: decide names field_mapper, attr_map, etc
    def initialize(plan_resources:, model:, field_mapping: {}, relationship_mapping: {}, logger: nil)
      @plan_resources = plan_resources
      @model = model
      @field_mapping = field_mapping
      @relationship_mapping = relationship_mapping
      @logger = logger
    end

    # Returns an ActiveRecord query for the Cerbos query plan.
    #
    # This returns the same +ActiveRecord::Relation+ type +Model.where(...)+ returns and can be used in the same way.
    # This allows refining queries further with a +where+ chain or other chained query interface methods.
    #
    # @return https://api.rubyonrails.org/classes/ActiveRecord/Relation.html
    def to_query
      log { inspect }
      query =
        if plan_resources.always_allowed?
          model.where('')
        elsif plan_resources.always_denied?
          model.where('1=0')
        elsif plan_resources.conditional?
          result = map_operands(plan_resources.condition)
          result.is_a?(ActiveRecord::Relation) ?
            model.merge(result) : model.where(result)
        else
          raise "Invalid Cerbos query plan: #{plan_resources.pretty_inspect}"
        end
      log(:to_query) { query.to_sql }
      query
    end

    def inspect
      fields = [:field_mapping, :relationship_mapping, :plan_resources].map { |f| "@#{f}:" << send(f).inspect }
      "#<#{self.class.name}:#{object_id} @model=#{model.name} #{fields.join(' ')}>"
    end

    private

    def expression?(operand)
      operand.is_a?(Cerbos::Output::PlanResources::Expression)
    end

    def value?(operand)
      operand.is_a?(Cerbos::Output::PlanResources::Expression::Value)
    end

    def variable?(operand)
      operand.is_a?(Cerbos::Output::PlanResources::Expression::Variable)
    end

    def get_operand_variable(operands)
      operands.find { |o| variable?(o) }&.name
    end

    def get_operand_value(operands)
      operands.find { |o| value?(o) }&.value
    end

    def get_operator_fn(operator, column, value)
      fn = OPERATOR_MAP[operator]
      raise "Unrecognised Cerbos query plan operator: #{operator}" if fn.nil?
      return fn.call(column, value, model)
    end

    def log(operation='', &block)
      logger.info(operation, &block) if logger
    end

    def map_operands(operand)
      operator = operand.operator
      operands = operand.operands

      log(:map_operands) { "#{operator}, operands: #{operands.inspect}" }
      raise "Query plan did not contain an operator expression" if operator.blank?

      if operator == "and"
        raise "Expected at least 2 operands" if operands.length < 2

        result = map_operands(operands.first)
        operands.drop(1).each do |operand|
          result = result.and(map_operands(operand))
        end

        return result
      end

      if operator == "or"
        raise "Expected at least 2 operands" if operands.length < 2

        result = map_operands(operands.first)
        operands.drop(1).each do |operand|
          result = result.or(map_operands(operand))
        end

        return result
      end

      if operator == "not"
        raise "Expected only 1 operand" if operands.length != 1

        result = map_operands(operands.first)
        if result.is_a? ActiveRecord::Relation
          return model.where.not("#{model.primary_key}" => result)
        else
          return Arel::Nodes::Not.new(result)
        end
      end

      variable = get_operand_variable(operands)
      value = get_operand_value(operands)
      relation = relationship_mapping[variable]

      if relation
        join_model = relation[:relation].to_sym
        column =  relation[:field].to_s
        model.joins(join_model).where( join_model => { column => value } )
      else
        column = field_mapping[variable]
        raise "Attribute #{variable} does not exist in the attribute field mapping: #{field_mapping}" if column.blank?

        # operator handlers here are leaf nodes of the recursion
        get_operator_fn(operator, column, value)
      end
    end
  end
end

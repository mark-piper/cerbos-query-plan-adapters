module Cerbos
  class QueryPlanAdapter
    attr_accessor :plan_resources, :model, :field_mapping, :relationship_mapping, :logger, :annotate

    class Configuration
      attr_accessor :logger, :annotate

      def initialize
        @logger = nil
        @annotate = true
      end
    end

    def self.configure
      yield config if block_given?
    end

    def self.config
      @@config ||= Configuration.new
    end

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
    def initialize(plan_resources:, model:, field_mapping: {}, relationship_mapping: {},
                   logger: config.logger, annotate: config.annotate)
      @plan_resources = plan_resources
      @model = model
      @field_mapping = field_mapping
      @relationship_mapping = relationship_mapping
      @logger = logger
      @annotate = annotate
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

      if annotate
        query = query.annotate("#<#{self.class.name} @model=#{model.name} @kind=#{plan_resources.kind}>")
      end

      if logger
        log(:to_query) { query.to_sql }
      end

      query
    end

    def inspect
      fields = [:field_mapping, :relationship_mapping, :plan_resources].map { |f| "@#{f}=" << send(f).inspect }
      "#<#{self.class.name}:#{object_id} @model=#{model.name} #{fields.join(' ')}>"
    end

    private

    def config
      self.class.config
    end

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

    # returns an ActiveRecord::Relation or an Arel::Node for the given +Cerbos::Output::PlanResources::Expression+
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
        # join_model accepts the same format as model.joins (SQL string, symbols, or hash with symbols),
        # or it can be omitted so that the caller can chain `to_query` with any custom join logic needed
        join_model = relation[:relation] || {}
        join_model = join_model.gsub("\n", " ").squeeze(" ") if join_model.is_a?(String)

        # one of column or field must be given (field is a symbol or hash with symbols, column is a SQL string)
        column = relation[:column]
        field =  relation[:field]
        raise "Missing column or field in the relationship mapping #{relation}" if (column.blank? && field.blank?)

        model.joins(join_model).where(column ? { column => value } : bury(bury(join_model, field), value))
      else
        column = field_mapping[variable]
        raise "Attribute #{variable} is not mapped in the field_mapping or relationship_mapping" if column.blank?

        # operator handlers here are leaf nodes of the recursion
        get_operator_fn(operator, column, value)
      end
    end

    # buries nested_value inside hash, eg: `bury({a: :b}, {c: :d})` returns `{a: {b: {c: :d}}}`
    def bury(hash, nested_value)
      # recursively flatten all the keys
      val = hash
      keys = []
      unless hash.empty?
        while (val.is_a?(Hash)) do
          k, val = val.first
          keys << k
        end
        keys << val
      end

      # reconstruct including nested_value
      if keys.empty?
        nested_value
      else
        result = h = {}
        while !keys.empty?
          k = keys.shift
          more = keys.length > 0
          h[k] = more ? {} : nested_value
          h = h[k] if more
        end
        result
      end
    end

  end
end

module ActiveRecord # :nodoc:
  module DynamicScope # :nodoc:
    class HasManyThroughWithoutDynamicScope < ActiveRecord::Associations::HasManyThroughAssociation
      protected
        def construct_conditions
          return super unless @reflection.through_reflection.klass.dynamic_scoped?
          table_name = @reflection.through_reflection.table_name
          conditions = construct_quoted_owner_attributes(@reflection.through_reflection).map do |attr, value|
            "#{table_name}.#{attr} = #{value}"
          end

          dynascope = @reflection.through_reflection.klass.send(:dynascope)
          conditions << dynascope[:conditions] if dynascope
          conditions << sql_conditions if sql_conditions

          "(" + conditions.join(') AND (') + ")"
        end
    end
  end
end
module Caboose # :nodoc:
  module Acts # :nodoc:
    class HasManyThroughWithoutDeletedAssociation < ActiveRecord::Associations::HasManyThroughAssociation
      protected
        def construct_conditions
          return super unless @reflection.through_reflection.klass.dynamic_scoped?
          table_name = @reflection.through_reflection.table_name
          conditions = construct_quoted_owner_attributes(@reflection.through_reflection).map do |attr, value|
            "#{table_name}.#{attr} = #{value}"
          end

          conditions << @reflection.through_reflection.klass.send(:dynascope)[:conditions]
          conditions << sql_conditions if sql_conditions
          "(" + conditions.join(') AND (') + ")"
        end
    end
  end
end
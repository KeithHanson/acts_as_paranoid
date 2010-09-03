class << ActiveRecord::Base
  def has_many_without_dynamic_scope(association_id, options = {}, &extension)
    returning has_many_with_dynamic_scope(association_id, options, &extension) do
      if options[:through]
        reflection = reflect_on_association(association_id)
        collection_reader_method(reflection, ActiveRecord::DynamicScope::HasManyThroughWithoutDynamicScope)
        collection_accessor_methods(reflection, ActiveRecord::DynamicScope::HasManyThroughWithoutDynamicScope, false)
      end
    end
  end
  
  alias_method :has_many_with_dynamic_scope, :has_many
  alias_method :has_many, :has_many_without_dynamic_scope
end

ActiveRecord::Base.send :include, ActiveRecord::DynamicScope::Paranoid

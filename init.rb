class << ActiveRecord::Base
  def belongs_to_with_deleted(association_id, options = {})
    returning belongs_to_without_deleted(association_id, options) do
    end
  end
  
  def has_many_without_deleted(association_id, options = {}, &extension)
    returning has_many_with_deleted(association_id, options, &extension) do
      if options[:through]
        reflection = reflect_on_association(association_id)
        collection_reader_method(reflection, Caboose::Acts::HasManyThroughWithoutDeletedAssociation)
        collection_accessor_methods(reflection, Caboose::Acts::HasManyThroughWithoutDeletedAssociation, false)
      end
    end
  end
  
  alias_method_chain :belongs_to, :deleted
  alias_method :has_many_with_deleted, :has_many
  alias_method :has_many, :has_many_without_deleted
end
ActiveRecord::Base.send :include, Caboose::Acts::Paranoid

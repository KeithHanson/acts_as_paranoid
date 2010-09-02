module ActiveRecord::Base::Paranoia
  def self.included(klass)
    klass.dynamic_scope :conditions => ["#{klass.table_name}.deleted_at IS NULL"]
    klass.extend ClassMethods
  end
  
  module ClassMethods
    def delete_all(conditions = nil)
      update_all ["deleted_at = ?", current_time], conditions
    end
  end

  def destroy_without_callbacks
    unless new_record?
      self.class.update_all self.class.send(:sanitize_sql, ["deleted_at = ?", (self.deleted_at = self.class.send(:current_time))]), ["#{self.class.primary_key} = ?", id]
    end
    freeze
  end
end

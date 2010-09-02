module Caboose #:nodoc:
  module Acts #:nodoc:
    # Overrides some basic methods for the current model so that calling #destroy sets a 'deleted_at' field to the current timestamp.
    # This assumes the table has a deleted_at date/time field.  Most normal model operations will work, but there will be some oddities.
    #
    #   class Widget < ActiveRecord::Base
    #     dynamic_scope
    #   end
    #
    #   Widget.find(:all)
    #   # SELECT * FROM widgets WHERE widgets.deleted_at IS NULL
    #
    #   Widget.find(:first, :conditions => ['title = ?', 'test'], :order => 'title')
    #   # SELECT * FROM widgets WHERE widgets.deleted_at IS NULL AND title = 'test' ORDER BY title LIMIT 1
    #
    #   Widget.find_with_deleted(:all)
    #   # SELECT * FROM widgets
    #
    #   Widget.find_only_deleted(:all)
    #   # SELECT * FROM widgets WHERE widgets.deleted_at IS NOT NULL
    #
    #   Widget.find_with_deleted(1).deleted?
    #   # Returns true if the record was previously destroyed, false if not 
    #
    #   Widget.count
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.deleted_at IS NULL
    #
    #   Widget.count ['title = ?', 'test']
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.deleted_at IS NULL AND title = 'test'
    #
    #   Widget.count_with_deleted
    #   # SELECT COUNT(*) FROM widgets
    #
    #   Widget.count_only_deleted
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.deleted_at IS NOT NULL
    #
    #   Widget.delete_all
    #   # UPDATE widgets SET deleted_at = '2005-09-17 17:46:36'
    #
    #   Widget.delete_all!
    #   # DELETE FROM widgets
    #
    #   @widget.destroy
    #   # UPDATE widgets SET deleted_at = '2005-09-17 17:46:36' WHERE id = 1
    #
    #   @widget.destroy!
    #   # DELETE FROM widgets WHERE id = 1
    # 
    module Paranoid
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def dynamic_scope(scope=nil)
          unless dynamic_scoped? # don't let AR call this twice
            include InstanceMethods
            cattr_accessor :dynascope
          end

          return self.dynascope if scope.nil?
          self.dynascope = scope
        end

        def dynamic_scoped?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end

        module ClassMethods
          def exists?(*args)
            with_dynascope { super }
          end

          def count(*args)
            with_dynascope { super }
          end

          def calculate(*args)
            with_dynascope { super }
          end

          protected
            def current_time
              default_timezone == :utc ? Time.now.to_date.utc : Time.now.to_date
            end

            def with_dynascope(&block)
              with_scope({:find => dynascope }, :merge, &block)
            end

          private
            # all find calls lead here
            def find_every(options)
              with_dynascope { super }
            end
        end
      end
    end
  end
end

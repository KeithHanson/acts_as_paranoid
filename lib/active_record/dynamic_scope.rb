module ActiveRecord # :nodoc:
  module DynamicScope # :nodoc:
    module Paranoid
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def dynamic_scope(scope=nil, &block)
          if block_given?
            raise "Extra parameter" unless scope.nil?
            scope = Proc.new
          end
          
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

          # Apparently count calls calculate
          #
          # def count(*args)
          #   super
          # end

          def calculate(*args)
            with_dynascope { super }
          end

          protected
            def current_time
              default_timezone == :utc ? Time.now.to_date.utc : Time.now.to_date
            end

            def with_dynascope(&block)
              d = dynascope
              d = d.call if d.respond_to?(:call)
              
              if d
                with_scope({:find => d }, :merge, &block)
              else
                yield
              end
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

module ActiveRecord::DynamicScope # :nodoc:
  def dynamic_scope(scope=nil, &block)
    if block_given?
      raise "Extra parameter" unless scope.nil?
      scope = Proc.new
    end
    
    unless dynamic_scoped? # don't let AR call this twice
      extend ClassMethods
      cattr_accessor :dynascope
    end

    return self.dynascope if scope.nil?
    self.dynascope = scope
  end

  def dynamic_scoped?
    self.respond_to? :dynascope
  end

  module ClassMethods
    # count etc. ends up here
    def calculate(*args)
      options = args.extract_options!
      options = options.dup if options.key?(:access)
        
      with_dynascope(options.delete(:access)) { 
        args.push options
        super 
      }
    end

    protected
    def with_dynascope(access, &block)
      d = dynascope
      d = d.call(access || :read) if d.respond_to?(:call)
      
      if d
        with_scope({:find => d }, :merge, &block)
      else
        yield
      end
    end

    private
    # all find calls lead here
    def find_every(options)
      options = options.dup if options.key?(:access)
      with_dynascope(options.delete(:access)) { super(options) }
    end
  end
end

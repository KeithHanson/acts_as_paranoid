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
      opts = args.extract_options!
      with_dynascope(opts) { 
        args.push opts
        super 
      }
    end

    def validate_find_options(options) #:nodoc:
      options = options.dup
      options.delete :access
      super
    end

    protected
    def with_dynascope(opts, &block)
      access = opts.delete(:access) || :read
      d = dynascope
      d = d.call(access) if d.respond_to?(:call)
      
      if d
        with_scope({:find => d }, :merge, &block)
      else
        yield
      end
    end

    private
    # all find calls lead here
    def find_every(opts)
      with_dynascope(opts) { 
        super(opts) 
      }
    end
    
  end
end

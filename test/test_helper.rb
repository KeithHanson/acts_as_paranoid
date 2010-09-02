$:.unshift(File.dirname(__FILE__) + '/../lib')

RAILS_ROOT = File.dirname(__FILE__) + "/.."

require 'rubygems'

require 'active_record'
require "active_record/base"
require "active_record/associations"
require "active_record/fixtures"
require "active_support/test_case"
require "action_controller"
require "test_help"

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
Dir["#{$LOAD_PATH.last}/**/*.rb"].sort.each do |path| 
  require path[$LOAD_PATH.last.size + 1..-1]
end
require File.join(File.dirname(__FILE__), '..', 'init.rb')

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))

ActiveRecord::Base.configurations.update(config) 
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite3'])

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/fixtures/")

class ActiveSupport::TestCase
  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  self.use_transactional_fixtures = true
  
  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
end

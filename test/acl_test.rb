require File.join(File.dirname(__FILE__), 'test_helper')
require File.join(File.dirname(__FILE__), 'schema/acl')

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"
end

class User < ActiveRecord::Base
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships, :class_name => 'User'
end

class Post < ActiveRecord::Base
end

class AclTest < ActiveSupport::TestCase
  fixtures :users, :friendships, :posts
  
  def test_fixtures
    assert_equal [users(:friend)], users(:one).friends
    assert_equal [users(:one)], users(:friend).friends
    assert_equal [], users(:other).friends
    #assert false
  end
end

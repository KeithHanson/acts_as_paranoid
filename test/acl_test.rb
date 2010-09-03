require File.join(File.dirname(__FILE__), 'test_helper')

module Acl
  def self.sudo(user)
    old = @current_user
    @current_user = user

    yield
  ensure
    @current_user = old
  end
  
  def self.current_user
    @current_user
  end
end

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"
end

class User < ActiveRecord::Base
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships, :class_name => 'User'

  has_many :posts
end

      
class ActiveRecord::Base
  def self.merge_or_conditions(*conditions)
    segments = []

    conditions.each do |condition|
      unless condition.blank?
        sql = sanitize_sql(condition)
        segments << sql unless sql.blank?
      end
    end

    "(#{segments.join(') OR (')})" unless segments.empty?
  end
end

class Post < ActiveRecord::Base
  belongs_to :user

  dynamic_scope do
    conditions = []
    if Acl.current_user
      conditions.push [ "user_id=?", Acl.current_user ]
      conditions.push [ 
        "posts.privacy='friends' AND user_id IN (SELECT friend_id FROM friendships WHERE user_id=?)", Acl.current_user ]
    end
    
    conditions.push "posts.privacy='public'"
    { :conditions => Post.merge_or_conditions(*conditions) }
  end

  validates_inclusion_of :privacy, :in => %w(private friends public)
end

class AclTest < ActiveSupport::TestCase
  fixtures :users, :friendships, :posts
  
  def test_fixtures
    assert_equal [users(:friend)], users(:one).friends
    assert_equal [users(:one)], users(:friend).friends
    assert_equal [], users(:other).friends
  end
  
  def test_on_base_class_for_guest
    assert_equal [3], Post.all.ids
    assert_raises(ActiveRecord::RecordNotFound) { Post.find(1).nil? }
  end
  
  def test_on_base_class_for_other
    Acl.sudo users(:other) do
      assert_equal [3], Post.all.ids
    end
  end
  
  def test_on_base_class_for_friend
    Acl.sudo users(:friend) do
      assert_equal [2,3], Post.all.ids
    end
  end
  
  def test_on_base_class_for_me
    Acl.sudo users(:one) do
      assert_equal [1,2,3], Post.all.ids
    end
  end
end

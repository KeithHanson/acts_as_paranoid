require File.join(File.dirname(__FILE__), 'test_helper')

#
# A simple ACL example.
#
# This module implements the following ACL strategy:
#
# An object with an owner_id attribute is owned by the specified owner (which
# is a User object). These objects support an optional privacy attribute, which
# might be one of "public", "private", "friends", "followers", "world"; 
# if the object does not support a "privacy" attribute this defaults to "private".
#
# Such objects can be read:
#
# - from the owner, when "private"
# - from the owner and his friends, when "friends"
# - from the owner, his friends, and his followers, when "protected"
# - from any User, when "public"
# - from any User and the "nil" special user, when "world"
#

#
# Thread local storage:
#
# Current.user(new_user) do 
#   Current.user # new_user
# end

module Current
  def self.method_missing(key, *args, &block)
    if args.length == 0 && !block_given?
      Thread.current[name]
    elsif args.length == 1 && block_given?
      exec_with_setting(key, args.first, &block)
    else
      super
    end
  end

  def self.exec_with_setting(key, value)
    old = Thread.current[name]
    Thread.current[name] = value
    yield
  ensure
    Thread.current[name] = old
  end
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

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"
end

class User < ActiveRecord::Base
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships, :class_name => 'User'

  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user

  dynamic_scope do
    conditions = []
    if Current.user
      conditions.push [ "user_id=?", Current.user ]
      conditions.push [ 
        "posts.privacy='friends' AND user_id IN (SELECT friend_id FROM friendships WHERE user_id=?)", Current.user ]
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
    Current.user(users(:other)) do
      assert_equal [3], Post.all.ids
    end
  end
  
  def test_on_base_class_for_friend
    Current.user(users(:friend)) do
      assert_equal [2,3], Post.all.ids
    end
  end
  
  def test_on_base_class_for_me
    Current.user(users(:one)) do
      assert_equal [1,2,3], Post.all.ids
    end
  end
end

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
# Read access is granted
#
# - to the owner, when "private"
# - to the owner and his friends, when "friends"
# - to the owner, his friends, and his followers, when "protected"
# - to any User, when "public"
# - to any User and the "nil" special user, when "world"
#
# Write access is granted to the owner only.
# Delete access is granted to the owner only.
# Create access is granted to everyone but the "nil" special user.
#


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

module Acl
  def self.acl?(klass)
    klass.column_names.include?("owner_id")
  end

  def self.privacy?(klass)
    acl?(klass) && klass.column_names.include?("privacy")
  end

  def self.for_owner(klass)
    return unless acl?(klass)
    return false unless Current.user

    t = klass.table_name
    [ "#{t}.owner_id=?", Current.user ]
  end
  
  def self.for_friends(klass)
    return unless privacy?(klass)
    return unless Current.user
    
    t = klass.table_name
    [ 
      "#{t}.privacy IN (?) AND #{t}.owner_id IN (SELECT friend_id FROM friendships WHERE friendships.user_id=?)", 
      %w(friends protected), 
      Current.user 
    ]
  end

  def self.for_followers(klass)
    return unless privacy?(klass)
    return unless Current.user
    
    t = klass.table_name
    [ 
      "#{t}.privacy IN (?) AND #{t}.owner_id IN (SELECT follower_id FROM followships WHERE followships.leader_id=?)", 
      %w(protected), 
      Current.user 
    ]
  end

  def self.for_public(klass)
    return unless privacy?(klass)
    return unless Current.user
    
    t = klass.table_name
    [ "#{t}.privacy='public'" ]
  end

  def self.for_world(klass)
    return unless privacy?(klass)
    
    t = klass.table_name
    [ "#{t}.privacy='world'" ]
  end

  def self.included(klass)
    klass.dynamic_scope do
      next nil if Current.user == :root

      conditions = []

      access = :read

      # grant read access
      #
      # - to the owner, when "private"
      # - to the owner and his friends, when "friends"
      # - to the owner, his friends, and his followers, when "protected"
      # - to any User, when "public"
      # - to any User and the "nil" special user, when "world"
      #
      
      conditions << for_owner(klass) << for_friends(klass) << for_followers(klass) << 
        for_public(klass) << for_world(klass)

      #
      # merge conditions
      segments = conditions.map do |condition|
        klass.send(:sanitize_sql, condition)
      end.compact

      conditions = "(#{segments.join(') OR (')})" 
      { :conditions => conditions }
    end
  end
end

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"
end

class Followship < ActiveRecord::Base
  belongs_to :follower, :class_name => "User"
  belongs_to :leader, :class_name => "User"
end

class User < ActiveRecord::Base
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships
  
  has_many :leaderships, :class_name => "Followship", :foreign_key => :leader_id
  has_many :followers, :through => :leaderships

  has_many :followships, :foreign_key => :follower_id
  has_many :leaders, :through => :followships
  
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :owner

  include Acl

  validates_inclusion_of :privacy, :in => %w(private friends public)
end

class AclTest < ActiveSupport::TestCase
  fixtures :users, :friendships, :posts, :followships
  
  def test_fixtures
    assert_equal [users(:friend)], users(:one).friends
    assert_equal [users(:one)], users(:friend).friends
    assert_equal [], users(:other).friends
    assert_equal [users(:follower)], users(:one).followers
    assert_equal [users(:one)], users(:follower).leaders
  end

  POST_NAMES = [ :private, :friends, :protected, :public, :world ]

  def setup
    setup_post_ids
  end
  
  def setup_post_ids
    Current.user(:root) do
      @post_ids = POST_NAMES.inject({}) do |hash, name|
        hash.update(name => posts(name).id)
      end
    end
  end

  def post_ids(*syms)
    syms.map { |sym| @post_ids.fetch(sym) }
  end
  
  def assert_user_sees(*expected_posts)
    expected_post_ids = post_ids(*expected_posts)
    assert_equal expected_post_ids.sort, Post.all.ids.sort

    expected_post_ids.each do |id|
      assert_equal id, Post.find(id).id
      assert_equal id, Post.find_by_id(id).id
    end
  end
  
  def assert_user_cannot_see(*unexpected_posts)
    unexpected_post_ids = post_ids(*unexpected_posts)
    assert_equal [], Post.all.ids & unexpected_post_ids
  
    unexpected_post_ids.each do |id|
      assert_raise(ActiveRecord::RecordNotFound) { Post.find(id) }
      assert_nil Post.find_by_id(id)
    end
  end
  
  def test_on_base_class_for_guest
    Current.user(nil) do
      assert_user_sees :world
      assert_user_cannot_see :public, :protected, :friends, :private
    end
  end
  
  def test_on_base_class_for_other
    Current.user(users(:other)) do
      assert_user_sees :public, :world
      assert_user_cannot_see :protected, :friends, :private
    end
  end
  
  def test_on_base_class_for_friend
    Current.user(users(:friend)) do
      assert_user_sees :world, :public, :protected, :friends
      assert_user_cannot_see :private
    end
  end
  
  def test_on_base_class_for_me
    Current.user(users(:one)) do
      assert_user_sees :world, :public, :protected, :friends, :private
      assert_user_cannot_see
    end
  end
end

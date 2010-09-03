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

class Thread
  module TLS
    def method_missing(key, *args, &block)
      if args.length == 0 && !block_given?
        self[key]
      elsif args.length == 1 && block_given?
        exec_with_setting(key, args.first, &block)
      else
        super
      end
    end

    def exec_with_setting(key, value)
      old = self[key]
      self[key] = value
      yield
    ensure
      self[key] = old
    end
  end
  
  include TLS
end

module Acl
  def self.acl?(klass)
    klass.column_names.include?("owner_id")
  end

  # grant read access
  #
  # - to the owner, when "private"
  # - to the owner and his friends, when "friends"
  # - to the owner, his friends, and his followers, when "protected"
  # - to any User, when "public"
  # - to any User and the "nil" special user, when "world"
  #
  def self.conditions_for(access, klass)
    t = klass.table_name
    u = Thread.current.user 
    conditions = []

    if u
      conditions << [ "#{t}.owner_id=?", u ]
    else
      conditions << [ "0" ]
    end

    return conditions if access != :read
    return unless klass.column_names.include?("privacy")

    if u

      sql = <<-SQL
  (#{t}.privacy IN ('friends', 'protected') AND #{t}.owner_id IN (SELECT friend_id FROM friendships WHERE friendships.user_id=?)) OR
  (#{t}.privacy='protected' AND #{t}.owner_id IN (SELECT leader_id FROM followships WHERE followships.follower_id=?)) OR
  (#{t}.privacy='public')
SQL

      conditions.push [ sql, u, u ]
    end

    conditions.push [ "#{t}.privacy='world'" ]
    conditions
  end
  
  def self.validate(rec) 
    if rec.new_record?
      rec.owner = Thread.current.user
      rec.privacy ||= "private"
      return
    end
    
    if !rec.class.find_by_id(rec.id, :access => :update)
      rec.errors.add_to_base "You are not allowed to update this record."
    end
  end
  
  def self.included(klass)
    klass.validate { |rec| validate(rec) }
    klass.validates_presence_of :owner_id
    klass.validates_inclusion_of :privacy, :in => %w(private protected friends public world)
    
    klass.dynamic_scope do |access|
      next nil if Thread.current.user == :root
      next nil unless acl?(klass)

      conditions = conditions_for(access, klass)
      
      next nil unless conditions
      
      conditions = "(" + 
        conditions.
          map { |condition| klass.send(:sanitize_sql, condition) }.
          compact.
          join(') OR (') +
        ")"

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
  belongs_to :owner, :class_name => "User"

  include Acl
end

class AclTest < ActiveSupport::TestCase
  fixtures :users, :friendships, :posts, :followships
  
  def test_fixtures
    assert_equal [users(:friend)], users(:one).friends
    assert_equal [users(:one), users(:friend_of_friend)], users(:friend).friends
    assert_equal [], users(:other).friends
    assert_equal [users(:follower)], users(:one).followers
    assert_equal [users(:one)], users(:follower).leaders
  end

  POST_NAMES = [ :private, :friends, :protected, :public, :world ]

  def post_ids(*syms)
    @post_ids ||= Thread.current.user(:root) do
      @post_ids = POST_NAMES.inject({}) do |hash, name|
        hash.update(name => posts(name).id)
      end
    end

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
  
  # -- basic visibility -------------------------------------------------------
  
  def test_on_base_class_for_guest
    Thread.current.user(nil) do
      assert_user_sees :world
      assert_user_cannot_see :public, :protected, :friends, :private
    end
  end
  
  def test_on_base_class_for_other
    Thread.current.user(users(:other)) do
      assert_user_sees :public, :world
      assert_user_cannot_see :protected, :friends, :private
    end
  end
  
  def test_on_base_class_for_friend
    Thread.current.user(users(:friend)) do
      assert_user_sees :world, :public, :protected, :friends
      assert_user_cannot_see :private
    end
  end
  
  def test_on_base_class_for_follower
    Thread.current.user(users(:follower)) do
      assert_user_sees :world, :public, :protected
      assert_user_cannot_see :private, :friends
    end
  end
  
  def test_on_base_class_for_me
    Thread.current.user(users(:one)) do
      assert_user_sees :world, :public, :protected, :friends, :private
      assert_user_cannot_see
    end
  end

  # -- creation
  def test_create_post
    assert_raise(ActiveRecord::RecordInvalid) { Post.create!(:text => "wha") }

    # create a private post
    p = nil
    Thread.current.user(users(:one)) do
      p = Post.create!(:text => "wha")
      assert p
      assert_equal p.reload.owner, users(:one)
    end
    
    assert_raise(ActiveRecord::RecordNotFound) { p.reload }

    # create a world post
    p = nil
    Thread.current.user(users(:one)) do
      p = Post.create!(:text => "wha", :privacy => "world")
      assert p
      assert_equal p.reload.owner, users(:one)
    end
    
    p1 = Post.find(p.id)
    assert_equal(p, p1)
  end
  
  def test_update_post
    Thread.current.user(users(:one)) do
      p = posts(:friends)
      p.update_attributes! :text => "fix"
    end

    Thread.current.user(users(:friend)) do
      p = posts(:friends)
      assert_raise(ActiveRecord::RecordInvalid) {
        p.update_attributes! :text => "updated"
      }
    end
  end
end

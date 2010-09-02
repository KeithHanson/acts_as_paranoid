require File.join(File.dirname(__FILE__), 'test_helper')

module Paranoia
  def self.included(klass)
    klass.dynamic_scope :conditions => ["#{klass.table_name}.deleted_at IS NULL"]
    klass.extend ClassMethods
  end
  
  module ClassMethods
    def delete_all(conditions = nil)
      update_all ["deleted_at = ?", current_time], conditions
    end
  end

  def destroy_without_callbacks
    unless new_record?
      self.class.update_all self.class.send(:sanitize_sql, ["deleted_at = ?", (self.deleted_at = self.class.send(:current_time))]), ["#{self.class.primary_key} = ?", id]
    end
    freeze
  end

  def destroy!
    transaction { destroy_with_callbacks }
  end
end

class Widget < ActiveRecord::Base
  include Paranoia
  
  has_many :categories, :dependent => :destroy
  has_and_belongs_to_many :habtm_categories, :class_name => 'Category'
  has_one :category
  belongs_to :parent_category, :class_name => 'Category'
  has_many :taggings
  has_many :tags, :through => :taggings
  has_many :any_tags, :through => :taggings, :class_name => 'Tag', :source => :tag
end

class Category < ActiveRecord::Base
  include Paranoia
  
  belongs_to :widget
  belongs_to :any_widget, :class_name => 'Widget', :foreign_key => 'widget_id'

  def self.search(name, options = {})
    find :all, options.merge(:conditions => ['LOWER(title) LIKE ?', "%#{name.to_s.downcase}%"])
  end
end

class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :widgets, :through => :taggings
end

class Tagging < ActiveRecord::Base
  include Paranoia
  
  belongs_to :tag
  belongs_to :widget
end

class NonParanoidAndroid < ActiveRecord::Base
end

class ParanoidTest < ActiveSupport::TestCase
  fixtures :widgets, :categories, :categories_widgets, :tags, :taggings
  
  def test_should_recognize_with_deleted_option
    assert_equal [1], Widget.find(:all).collect { |w| w.id }
  end
    
  def test_should_exists_with_deleted
    assert !Widget.exists?(2)
  end

  def test_should_count_with_deleted
    assert_equal 1, Widget.count
  end

  def test_should_set_deleted_at
    assert_equal 1, Widget.count
    assert_equal 1, Category.count
    widgets(:widget_1).destroy
    assert_equal 0, Widget.count
    assert_equal 0, Category.count
  end
  
  def test_should_destroy
    assert_equal 1, Widget.count
    assert_equal 1, Category.count
    widgets(:widget_1).destroy!
    assert_equal 0, Widget.count
    assert_equal 0, Category.count
  end
  
  def test_should_delete_all
    assert_equal 1, Widget.count
    assert_equal 1, Category.count
    Widget.delete_all
    assert_equal 0, Widget.count
    # delete_all doesn't call #destroy, so the dependent callback never fires
    assert_equal 1, Category.count
  end
  
  def test_should_delete_all_with_conditions
    assert_equal 1, Widget.count
    Widget.delete_all("id < 3")
    assert_equal 0, Widget.count
  end
  
  def test_should_delete_all2
    assert_equal 1, Category.count
    Category.destroy_all
    assert_equal 0, Category.count
  end
  
  def test_should_delete_all_with_conditions2
    assert_equal 1, Category.count
    Category.destroy_all("id < 3")
    assert_equal 0, Category.count
  end
  
  def test_should_not_count_deleted
    assert_equal 1, Widget.count
    assert_equal 1, Widget.count(:all, :conditions => ['title=?', 'widget 1'])
  end
  
  def test_should_not_find_deleted
    assert_equal [widgets(:widget_1)], Widget.find(:all)
  end
  
  def test_should_not_find_deleted_has_many_associations
    assert_equal 1, widgets(:widget_1).categories.size
    assert_equal [categories(:category_1)], widgets(:widget_1).categories
  end
  
  def test_should_not_find_deleted_habtm_associations
    assert_equal 1, widgets(:widget_1).habtm_categories.size
    assert_equal [categories(:category_1)], widgets(:widget_1).habtm_categories
  end
  
  def test_should_not_find_deleted_has_many_through_associations
    assert_equal 1, widgets(:widget_1).tags.size
    assert_equal [tags(:tag_2)], widgets(:widget_1).tags
  end
  
  def test_should_find_single_id
    assert Widget.find(1)
    assert_raises(ActiveRecord::RecordNotFound) { Widget.find(2) }
  end
  
  def test_should_find_multiple_ids
    assert_raises(ActiveRecord::RecordNotFound) { Widget.find(1,2) }
  end
  
  def test_should_ignore_multiple_includes
    Widget.class_eval { dynamic_scope }
    assert Widget.find(1)
  end

  def test_should_not_override_scopes_when_counting
    assert_equal 1, Widget.send(:with_scope, :find => { :conditions => "title = 'widget 1'" }) { Widget.count }
    assert_equal 0, Widget.send(:with_scope, :find => { :conditions => "title = 'deleted widget 2'" }) { Widget.count }
  end

  def test_should_not_override_scopes_when_finding
    assert_equal [1], Widget.send(:with_scope, :find => { :conditions => "title = 'widget 1'" }) { Widget.find(:all) }.ids
    assert_equal [],  Widget.send(:with_scope, :find => { :conditions => "title = 'deleted widget 2'" }) { Widget.find(:all) }.ids
  end

  def test_should_allow_multiple_scoped_calls_when_finding
    Widget.send(:with_scope, :find => { :conditions => "title = 'deleted widget 2'" }) do
      assert_equal [], Widget.find(:all).ids
    end
  end

  def test_should_allow_multiple_scoped_calls_when_counting
    Widget.send(:with_scope, :find => { :conditions => "title = 'deleted widget 2'" }) do
      assert_equal 0, Widget.count
    end
  end

  def test_should_give_paranoid_status
    assert_equal({:conditions=>["widgets.deleted_at IS NULL"]}, Widget.dynamic_scope)
    assert NonParanoidAndroid.dynamic_scope.nil?
  end

  def test_dynamic_finders
    assert     Widget.find_by_id(1)
    assert_nil Widget.find_by_id(2)
  end
end

class Array
  def ids
    collect &:id
  end
end

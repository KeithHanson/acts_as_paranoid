ActiveRecord::Schema.define(:version => 1) do

  create_table :users, :force => true do |t|
    t.column :name, :string
  end

  create_table :friendships, :force => true do |t|
    t.column :user_id, :integer
    t.column :friend_id, :integer
  end

  create_table :followships, :force => true do |t|
    t.column :leader_id, :integer
    t.column :follower_id, :integer
  end

  create_table :posts, :force => true do |t|
    t.column :text, :string
    t.column :owner_id, :integer
    t.column :privacy, :string
  end
end

require "test_helper"

class StatementTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123456",
      password_confirmation: "password123456"
    )
  end

  test "should be valid with content and author" do
    statement = Statement.new(content: "the world is round", author: @user)
    assert statement.valid?
  end

  test "should require content" do
    statement = Statement.new(author: @user)
    assert_not statement.valid?
    assert_includes statement.errors[:content], "can't be blank"
  end

  test "should require author" do
    statement = Statement.new(content: "test content")
    assert_not statement.valid?
  end

  # Normalization tests
  test "should remove trailing period" do
    statement = Statement.create!(content: "the world is round.", author: @user)
    assert_equal "the world is round", statement.content
  end

  test "should lowercase first letter if not proper noun" do
    statement = Statement.create!(content: "The world is round", author: @user)
    assert_equal "the world is round", statement.content
  end

  test "should keep proper noun capitalized - days" do
    statement = Statement.create!(content: "Monday is great", author: @user)
    assert_equal "Monday is great", statement.content
  end

  test "should keep proper noun capitalized - months" do
    statement = Statement.create!(content: "January is cold", author: @user)
    assert_equal "January is cold", statement.content
  end

  test "should keep proper noun capitalized - places" do
    statement = Statement.create!(content: "America is diverse", author: @user)
    assert_equal "America is diverse", statement.content
  end

  test "should keep acronyms capitalized" do
    statement = Statement.create!(content: "NASA explores space", author: @user)
    assert_equal "NASA explores space", statement.content
  end

  test "should keep pronoun I capitalized" do
    statement = Statement.create!(content: "I like pizza", author: @user)
    assert_equal "I like pizza", statement.content
  end

  test "should lowercase non-proper nouns" do
    statement = Statement.create!(content: "People are kind", author: @user)
    assert_equal "people are kind", statement.content
  end

  test "should handle both normalizations together" do
    statement = Statement.create!(content: "The world is round.", author: @user)
    assert_equal "the world is round", statement.content
  end

  # Hierarchy tests
  test "should create parent-child relationship" do
    parent = Statement.create!(content: "parent statement", author: @user)
    child = Statement.create!(content: "child statement", author: @user, parent: parent)

    assert_equal parent, child.parent
    assert_includes parent.children, child
  end

  test "should support multiple children" do
    parent = Statement.create!(content: "parent statement", author: @user)
    child1 = Statement.create!(content: "child 1", author: @user, parent: parent)
    child2 = Statement.create!(content: "child 2", author: @user, parent: parent)

    assert_equal 2, parent.children.count
    assert_includes parent.children, child1
    assert_includes parent.children, child2
  end

  test "should find ancestors with closure_tree" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent = Statement.create!(content: "parent", author: @user, parent: grandparent)
    child = Statement.create!(content: "child", author: @user, parent: parent)

    assert_includes child.ancestors, parent
    assert_includes child.ancestors, grandparent
  end

  test "should find descendants with closure_tree" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent = Statement.create!(content: "parent", author: @user, parent: grandparent)
    child = Statement.create!(content: "child", author: @user, parent: parent)

    assert_includes grandparent.descendants, parent
    assert_includes grandparent.descendants, child
  end

  test "should find all ancestors using all_ancestors method" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent = Statement.create!(content: "parent", author: @user, parent: grandparent)
    child = Statement.create!(content: "child", author: @user, parent: parent)

    ancestors = child.all_ancestors
    assert_equal 2, ancestors.length
    assert_includes ancestors, parent
    assert_includes ancestors, grandparent
  end

  test "all_ancestors should return empty array for root statement" do
    root = Statement.create!(content: "root", author: @user)
    assert_equal [], root.all_ancestors
  end

  test "descendant_count should count all descendants recursively" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent1 = Statement.create!(content: "parent 1", author: @user, parent: grandparent)
    parent2 = Statement.create!(content: "parent 2", author: @user, parent: grandparent)
    child1 = Statement.create!(content: "child 1", author: @user, parent: parent1)
    child2 = Statement.create!(content: "child 2", author: @user, parent: parent1)
    child3 = Statement.create!(content: "child 3", author: @user, parent: parent2)

    # Grandparent should have 5 descendants (2 children + 3 grandchildren)
    assert_equal 5, grandparent.descendant_count
    # Parent1 should have 2 descendants (2 children)
    assert_equal 2, parent1.descendant_count
    # Parent2 should have 1 descendant (1 child)
    assert_equal 1, parent2.descendant_count
    # Children should have 0 descendants
    assert_equal 0, child1.descendant_count
  end

  test "all_descendants should return all descendants recursively" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent1 = Statement.create!(content: "parent 1", author: @user, parent: grandparent)
    parent2 = Statement.create!(content: "parent 2", author: @user, parent: grandparent)
    child1 = Statement.create!(content: "child 1", author: @user, parent: parent1)
    child2 = Statement.create!(content: "child 2", author: @user, parent: parent1)
    child3 = Statement.create!(content: "child 3", author: @user, parent: parent2)

    # Grandparent should have all 5 descendants
    descendants = grandparent.all_descendants
    assert_equal 5, descendants.length
    assert_includes descendants, parent1
    assert_includes descendants, parent2
    assert_includes descendants, child1
    assert_includes descendants, child2
    assert_includes descendants, child3

    # Parent1 should have 2 descendants
    assert_equal 2, parent1.all_descendants.length
    assert_includes parent1.all_descendants, child1
    assert_includes parent1.all_descendants, child2

    # Children should have no descendants
    assert_equal [], child1.all_descendants
  end
end

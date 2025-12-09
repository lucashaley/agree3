require "test_helper"

class StatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123456",
      password_confirmation: "password123456"
    )

    # Sign in by creating a session and setting the cookie
    sign_in_user(@user)

    @statement = Statement.create!(content: "test statement", author: @user)
  end

  test "should get index" do
    get statements_url
    assert_response :success
  end

  test "should show statement" do
    get statement_url(@statement)
    assert_response :success
  end

  test "should get new" do
    get new_statement_url
    assert_response :success
  end

  test "should create statement" do
    assert_difference("Statement.count") do
      post statements_url, params: { statement: { content: "new statement" } }
    end

    assert_redirected_to statement_url(Statement.last)
    assert_equal @user, Statement.last.author
  end

  test "should not create statement without content" do
    assert_no_difference("Statement.count") do
      post statements_url, params: { statement: { content: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_statement_url(@statement)
    assert_response :success
  end

  test "should update statement" do
    patch statement_url(@statement), params: { statement: { content: "updated content" } }
    assert_redirected_to statement_url(@statement)

    @statement.reload
    assert_equal "updated content", @statement.content
  end

  test "should destroy statement" do
    assert_difference("Statement.count", -1) do
      delete statement_url(@statement)
    end

    assert_redirected_to statements_url
  end

  # Voting tests
  test "should agree with statement" do
    post agree_statement_url(@statement)
    assert_redirected_to statement_url(@statement)

    assert @user.voted_for?(@statement)
  end

  test "should unagree with statement" do
    @statement.vote_by voter: @user

    post agree_statement_url(@statement)
    assert_redirected_to statement_url(@statement)

    assert_not @user.voted_for?(@statement)
  end

  test "should toggle agreement on multiple clicks" do
    # First click - agree
    post agree_statement_url(@statement)
    assert @user.voted_for?(@statement)

    # Second click - unagree
    post agree_statement_url(@statement)
    assert_not @user.voted_for?(@statement)

    # Third click - agree again
    post agree_statement_url(@statement)
    assert @user.voted_for?(@statement)
  end

  # Variant tests
  test "should create variant with parent relationship" do
    assert_difference("Statement.count") do
      post create_variant_statement_url(@statement), params: {
        statement: { content: "variant statement" }
      }
    end

    variant = Statement.last
    assert_equal @statement, variant.parent
    assert_redirected_to statement_url(variant)
  end

  test "should create variant with modified content" do
    original_content = @statement.content

    post create_variant_statement_url(@statement), params: {
      statement: { content: "modified variant" }
    }

    variant = Statement.last
    assert_equal "modified variant", variant.content
    assert_not_equal original_content, variant.content
    assert_equal @statement, variant.parent
  end

  test "variant should be a descendant" do
    post create_variant_statement_url(@statement), params: {
      statement: { content: "variant statement" }
    }

    variant = Statement.last
    assert_includes @statement.descendants, variant
    assert_includes variant.ancestors, @statement
  end

  test "should not create variant without content" do
    assert_no_difference("Statement.count") do
      post create_variant_statement_url(@statement), params: {
        statement: { content: "" }
      }
    end

    assert_redirected_to statement_url(@statement)
  end

  # Ancestor voting tests
  test "should warn when voting for statement with voted ancestor" do
    parent = Statement.create!(content: "parent statement", author: @user)
    child = Statement.create!(content: "child statement", author: @user, parent: parent)

    # Vote for parent first
    parent.vote_by voter: @user
    assert @user.voted_for?(parent)

    # Try to vote for child - should get warning
    post agree_statement_url(child)
    assert_redirected_to statement_url(child)
    assert flash[:ancestor_warning].present?
    assert_equal ["parent statement"], flash[:ancestor_warning]['ancestor_contents']

    # User should still have parent vote, not child vote
    assert @user.voted_for?(parent)
    assert_not @user.voted_for?(child)
  end

  test "should remove ancestor vote when confirmed" do
    parent = Statement.create!(content: "parent statement", author: @user)
    child = Statement.create!(content: "child statement", author: @user, parent: parent)

    # Vote for parent first
    parent.vote_by voter: @user
    assert @user.voted_for?(parent)

    # Vote for child with confirmation - should remove parent vote
    post agree_statement_url(child), params: { confirm_ancestor_removal: 'true' }
    assert_redirected_to statement_url(child)

    # User should now have child vote, not parent vote
    assert_not @user.voted_for?(parent)
    assert @user.voted_for?(child)
  end

  test "should handle multiple ancestor votes" do
    grandparent = Statement.create!(content: "grandparent", author: @user)
    parent = Statement.create!(content: "parent", author: @user, parent: grandparent)
    child = Statement.create!(content: "child", author: @user, parent: parent)

    # Vote for both ancestors
    grandparent.vote_by voter: @user
    parent.vote_by voter: @user

    # Try to vote for child with confirmation
    post agree_statement_url(child), params: { confirm_ancestor_removal: 'true' }

    # All ancestor votes should be removed, child should be voted
    assert_not @user.voted_for?(grandparent)
    assert_not @user.voted_for?(parent)
    assert @user.voted_for?(child)
  end
end

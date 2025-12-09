require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123456",
      password_confirmation: "password123456"
    )
  end

  test "should be valid with email and password" do
    assert @user.valid?
  end

  test "should have statements association" do
    statement = Statement.create!(content: "test statement", author: @user)

    assert_includes @user.statements, statement
    assert_equal @user, statement.author
  end

  test "should be able to vote for statements" do
    statement = Statement.create!(content: "test statement", author: @user)

    statement.vote_by voter: @user

    assert @user.voted_for?(statement)
  end

  test "should be able to unvote for statements" do
    statement = Statement.create!(content: "test statement", author: @user)

    statement.vote_by voter: @user
    assert @user.voted_for?(statement)

    statement.unvote_by(@user)
    assert_not @user.voted_for?(statement)
  end

  test "should have multiple statements" do
    statement1 = Statement.create!(content: "statement 1", author: @user)
    statement2 = Statement.create!(content: "statement 2", author: @user)

    assert_equal 2, @user.statements.count
    assert_includes @user.statements, statement1
    assert_includes @user.statements, statement2
  end

  test "should destroy associated statements when user is destroyed" do
    statement = Statement.create!(content: "test statement", author: @user)
    statement_id = statement.id

    assert_difference("Statement.count", -1) do
      @user.destroy
    end

    assert_nil Statement.find_by(id: statement_id)
  end
end

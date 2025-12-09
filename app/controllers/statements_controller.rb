class StatementsController < ApplicationController
  before_action :set_statement, only: %i[ show edit update destroy agree create_variant ]

  # GET /statements or /statements.json
  def index
    @statements = Statement.all
    # Get top 10 statements by vote count
    @top_statements = Statement.all.sort_by { |s| s.get_upvotes.size }.reverse.take(10)
    # Get top 10 statements by number of descendants (variants)
    @top_by_variants = Statement.all.select { |s| s.children.any? }.sort_by { |s| s.descendant_count }.reverse.take(10)
    # Get 10 most recent statements
    @recent_statements = Statement.order(created_at: :desc).limit(10)
  end

  # GET /statements/1 or /statements/1.json
  def show
  end

  # GET /statements/new
  def new
    @statement = Statement.new
  end

  # GET /statements/1/edit
  def edit
  end

  # POST /statements or /statements.json
  def create
    @statement = Statement.new(statement_params)
    @statement.author = Current.user

    respond_to do |format|
      if @statement.save
        format.html { redirect_to @statement, notice: "Statement was successfully created." }
        format.json { render :show, status: :created, location: @statement }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /statements/1 or /statements/1.json
  def update
    respond_to do |format|
      if @statement.update(statement_params)
        format.html { redirect_to @statement, notice: "Statement was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @statement }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /statements/1 or /statements/1.json
  def destroy
    @statement.destroy!

    respond_to do |format|
      format.html { redirect_to statements_path, notice: "Statement was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /statements/1/agree
  def agree
    Rails.logger.info "=== AGREE ACTION ==="
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "confirm_ancestor_removal param: #{params[:confirm_ancestor_removal]}"

    if Current.user.voted_for? @statement
      # Unvote - just remove the vote
      Rails.logger.info "Unvoting from statement"
      @statement.unvote_by Current.user
      redirect_to @statement
    else
      # Check if user has voted for any ancestors
      voted_ancestors = @statement.all_ancestors.select { |ancestor| Current.user.voted_for?(ancestor) }
      Rails.logger.info "Voted ancestors: #{voted_ancestors.map(&:id).inspect}"

      if voted_ancestors.any? && params[:confirm_ancestor_removal] != 'true'
        # Store ancestor info in flash and redirect back for confirmation
        Rails.logger.info "Showing warning modal"
        flash[:ancestor_warning] = {
          'statement_id' => @statement.id,
          'ancestor_contents' => voted_ancestors.map(&:content)
        }
        redirect_to @statement
      else
        # Remove votes from ancestors if confirming
        Rails.logger.info "Confirmed - removing #{voted_ancestors.count} ancestor votes"
        voted_ancestors.each do |ancestor|
          Rails.logger.info "Removing vote from ancestor #{ancestor.id}"
          ancestor.unvote_by(Current.user)
          Rails.logger.info "After unvote, user voted for ancestor #{ancestor.id}? #{Current.user.voted_for?(ancestor)}"
        end

        # Vote for current statement
        Rails.logger.info "Voting for current statement #{@statement.id}"
        @statement.vote_by voter: Current.user
        Rails.logger.info "After vote, user voted for statement? #{Current.user.voted_for?(@statement)}"
        redirect_to @statement
      end
    end
  end

  # POST /statements/1/create_variant
  def create_variant
    @variant = Statement.new(statement_params)
    @variant.author = Current.user
    @variant.parent = @statement

    if @variant.save
      redirect_to @variant, notice: "Variant was successfully created."
    else
      redirect_to @statement, alert: "Failed to create variant: #{@variant.errors.full_messages.join(', ')}"
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_statement
      @statement = Statement.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def statement_params
      params.expect(statement: [ :content ])
    end
end

class StatementsController < ApplicationController
  before_action :set_statement, only: %i[ show edit update destroy agree create_variant svg ]

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

      if voted_ancestors.any? && params[:confirm_ancestor_removal] != "true"
        # Store ancestor info in flash and redirect back for confirmation
        Rails.logger.info "Showing warning modal"
        flash[:ancestor_warning] = {
          "statement_id" => @statement.id,
          "ancestor_contents" => voted_ancestors.map(&:content)
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

  # GET /statements/1/svg
  def svg
    # Set SVG dimensions
    size = 512
    padding = 40

    # Prepare text
    header = "we agree that..."
    content = @statement.content
    content += "." unless content.end_with?(".", "!", "?")

    # Calculate header dimensions
    header_size = 24
    header_line_height = header_size * 1.2
    header_total_height = header_line_height + 20 # header + spacing

    # Calculate available space for content
    available_width = size - (padding * 2)
    available_height = size - (padding * 2) - header_total_height

    # Calculate optimal font size that fills the space
    content_size = calculate_optimal_font_size(content, available_width, available_height)

    # Generate SVG
    svg_content = <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{size}" height="#{size}" xmlns="http://www.w3.org/2000/svg">
        <rect width="#{size}" height="#{size}" fill="#f8f9fa"/>
        <text x="#{padding}" y="#{padding + header_size}"
              font-family="'Jost', sans-serif"
              font-size="#{header_size}"
              font-weight="600"
              fill="#111827"
              text-anchor="left">
          #{header}
        </text>
        <text x="#{padding}" y="#{padding + header_total_height + content_size}"
              font-family="'Jost', sans-serif"
              font-size="#{content_size}"
              font-weight="600"
              fill="#111827"
              text-anchor="left">
          #{wrap_text(content, available_width, content_size)}
        </text>
      </svg>
    SVG

    render xml: svg_content, content_type: "image/svg+xml"
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

    # Calculate optimal font size to fill available space
    def calculate_optimal_font_size(text, max_width, max_height)
      # Start with a reasonable range
      min_size = 16
      max_size = 120
      optimal_size = min_size

      # Test sizes from large to small to find the biggest that fits
      max_size.downto(min_size) do |font_size|
        lines = wrap_text_to_lines(text, max_width, font_size)
        line_height = font_size * 1.2
        total_height = lines.length * line_height

        # If this size fits, it's our optimal size
        if total_height <= max_height
          optimal_size = font_size
          break
        end
      end

      optimal_size
    end

    # Wrap text into lines based on available width and font size
    def wrap_text_to_lines(text, max_width, font_size)
      words = text.split(" ")
      lines = []
      current_line = []

      # Character width estimate (adjust based on your font)
      # Jost font is roughly 0.6 * font_size per character on average
      char_width = font_size * 0.6

      words.each do |word|
        test_line = (current_line + [ word ]).join(" ")
        line_width = test_line.length * char_width

        if line_width > max_width && current_line.any?
          lines << current_line.join(" ")
          current_line = [ word ]
        else
          current_line << word
        end
      end
      lines << current_line.join(" ") if current_line.any?

      lines
    end

    # Helper to wrap text into multiple lines for SVG with tspan elements
    def wrap_text(text, max_width, font_size)
      lines = wrap_text_to_lines(text, max_width, font_size)

      # Generate tspan elements for each line
      lines.map.with_index do |line, i|
        %(<tspan x="40" dy="#{i == 0 ? 0 : font_size * 1.2}">#{line}</tspan>)
      end.join("\n          ")
    end
end

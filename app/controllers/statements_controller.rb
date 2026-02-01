class StatementsController < ApplicationController
  before_action :require_authentication, only: %i[ new create edit update destroy agree create_variant flag unflag ]
  before_action :set_statement, only: %i[ show edit update destroy agree create_variant svg png jpg flag unflag ]

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

  # GET /statements/search
  def search
    if params[:q].present?
      @statements = Statement.search_by_content(params[:q])
    else
      @statements = []
    end
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
    # Verify ALTCHA challenge
    unless AltchaSolution.verify_and_save(params.permit(:altcha)[:altcha])
      @statement = Statement.new(statement_params)
      @statement.errors.add(:base, "Please complete the verification challenge")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
      return
    end

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

  # POST /statements/1/flag
  def flag
    flag_type = params[:flag_type]

    if Statement::FLAG_TYPES.include?(flag_type)
      # Check if user hasn't already flagged with this type
      tag = ActsAsTaggableOn::Tag.find_or_create_by(name: flag_type)
      unless @statement.taggings.exists?(tag: tag, tagger: Current.user, context: :flags)
        @statement.taggings.create!(
          tag: tag,
          tagger: Current.user,
          context: :flags
        )
      end
      redirect_to @statement, notice: "Statement flagged as #{flag_type}."
    else
      redirect_to @statement, alert: "Invalid flag type."
    end
  end

  # DELETE /statements/1/unflag
  def unflag
    flag_type = params[:flag_type]

    # Remove only the current user's flag of this type
    tagging = @statement.taggings.where(
      tag: ActsAsTaggableOn::Tag.find_by(name: flag_type),
      tagger: Current.user,
      context: :flags
    ).first

    if tagging
      tagging.destroy
      redirect_to @statement, notice: "Flag removed."
    else
      redirect_to @statement, alert: "Flag not found."
    end
  end

  # POST /statements/sync_agreements
  # Sync localStorage agreements to user account when they sign in
  def sync_agreements
    return head :unauthorized unless Current.user

    statement_ids = params[:statement_ids] || []

    # Vote for each statement the user agreed to while anonymous
    synced_count = 0
    statement_ids.each do |statement_id|
      statement = Statement.find_by(id: statement_id)
      next unless statement

      # Only add vote if user hasn't already voted
      unless Current.user.voted_for?(statement)
        statement.vote_by voter: Current.user
        synced_count += 1
      end
    end

    render json: { success: true, synced: synced_count }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /statements/1/svg
  def svg
    svg_content = generate_svg_content(@statement, params[:mode])
    render xml: svg_content, content_type: "image/svg+xml"
  end

  # GET /statements/1/png
  def png
    require "mini_magick"
    require "tempfile"

    Rails.logger.info "PNG action called for statement #{@statement.id}"

    svg_content = generate_svg_content(@statement, params[:mode])
    Rails.logger.info "SVG generated, length: #{svg_content.length}"

    # Write SVG to tempfile, then convert to PNG
    Tempfile.create([ "statement", ".svg" ]) do |svg_file|
      svg_file.write(svg_content)
      svg_file.rewind

      image = MiniMagick::Image.open(svg_file.path)
      image.format "png"

      png_blob = image.to_blob
      Rails.logger.info "PNG converted successfully, blob size: #{png_blob.bytesize} bytes"

      send_data png_blob, type: "image/png", disposition: "inline"
    end
  rescue => e
    Rails.logger.error "PNG conversion error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render plain: "Error generating PNG: #{e.class.name}: #{e.message}\n\n#{e.backtrace.first(10).join("\n")}", status: :internal_server_error
  end

  # GET /statements/1/jpg
  def jpg
    require "mini_magick"
    require "tempfile"

    Rails.logger.info "JPG action called for statement #{@statement.id}"

    svg_content, background_color = generate_svg_content(@statement, params[:mode], return_colors: true)
    Rails.logger.info "SVG generated, length: #{svg_content.length}, bg: #{background_color}"

    # Write SVG to tempfile, then convert to JPG
    Tempfile.create([ "statement", ".svg" ]) do |svg_file|
      svg_file.write(svg_content)
      svg_file.rewind

      image = MiniMagick::Image.open(svg_file.path)
      image.format "jpg"
      image.quality "95"
      image.background background_color
      image.flatten

      jpg_blob = image.to_blob
      Rails.logger.info "JPG converted successfully, blob size: #{jpg_blob.bytesize} bytes"

      send_data jpg_blob, type: "image/jpeg", disposition: "inline"
    end
  rescue => e
    Rails.logger.error "JPG conversion error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render plain: "Error generating JPG: #{e.class.name}: #{e.message}\n\n#{e.backtrace.first(10).join("\n")}", status: :internal_server_error
  end

  # GET /statements/1/og_image
  # Serve the pre-generated Facebook Open Graph image (1200x630)
  def og_image
    if @statement.og_image.attached?
      redirect_to rails_blob_path(@statement.og_image, disposition: "inline")
    else
      # Fallback: image is being generated by background job
      render plain: "OG image is being generated, please try again in a moment", status: :accepted
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

    # Generate SVG content for a statement
    def generate_svg_content(statement, mode_param = nil, return_colors: false)
      # Set SVG dimensions
      size = 512
      padding = 40

      # Prepare text
      header = "we agree that..."
      content = statement.content
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

      # Determine color scheme based on mode parameter
      mode = mode_param == "dark" ? "dark" : "light"
      colors = if mode == "dark"
        {
          background: "#111827",
          text: "#f9fafb",
          header: "#9ca3af"
        }
      else
        {
          background: "#f8f9fa",
          text: "#111827",
          header: "#6b7280"
        }
      end

      # Generate SVG
      # Use Futura Bold for ImageMagick compatibility
      svg_content = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="#{size}" height="#{size}" xmlns="http://www.w3.org/2000/svg">
          <rect width="#{size}" height="#{size}" fill="#{colors[:background]}"/>
          <text x="#{padding}" y="#{padding + header_size}"
                font-family="Futura, sans-serif"
                font-size="#{header_size}"
                font-weight="700"
                fill="#{colors[:header]}"
                text-anchor="left">
            #{header}
          </text>
          <text x="#{padding}" y="#{padding + header_total_height + content_size}"
                font-family="Futura, sans-serif"
                font-size="#{content_size}"
                font-weight="700"
                fill="#{colors[:text]}"
                text-anchor="left">
            #{wrap_text(content, available_width, content_size)}
          </text>
        </svg>
      SVG

      return_colors ? [ svg_content, colors[:background] ] : svg_content
    end
end

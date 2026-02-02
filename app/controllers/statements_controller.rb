class StatementsController < ApplicationController
  before_action :require_authentication, only: %i[ new create edit update destroy agree create_variant flag unflag ]
  before_action :set_statement, only: %i[ show edit update destroy agree create_variant square_png square_png_dark social_jpg social_jpg_dark og_image flag unflag ]

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
    # If OG image is attached (SVG), use Cloudinary transformation
    if @statement.og_image.attached? && @statement.og_image.content_type == "image/svg+xml"
      redirect_to @statement.og_image.url(
        transformation: [
          { fetch_format: :png }
        ]
      ), status: :moved_permanently
    else
      # Fallback to dynamic SVG generation and MiniMagick conversion
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
    end
  rescue => e
    Rails.logger.error "PNG conversion error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render plain: "Error generating PNG: #{e.class.name}: #{e.message}\n\n#{e.backtrace.first(10).join("\n")}", status: :internal_server_error
  end

  # GET /statements/1/jpg
  def jpg
    # If OG image is attached (SVG), use Cloudinary transformation
    if @statement.og_image.attached? && @statement.og_image.content_type == "image/svg+xml"
      redirect_to @statement.og_image.url(
        transformation: [
          { fetch_format: :jpg, quality: 95 }
        ]
      ), status: :moved_permanently
    else
      # Fallback to dynamic SVG generation and MiniMagick conversion
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
    end
  rescue => e
    Rails.logger.error "JPG conversion error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render plain: "Error generating JPG: #{e.class.name}: #{e.message}\n\n#{e.backtrace.first(10).join("\n")}", status: :internal_server_error
  end

  # GET /statements/:id/square
  # Redirect to square image (512x512) on Cloudinary
  def square_png
    if @statement.square_image_public_id.present?
      redirect_to cl_image_path(@statement.square_image_public_id, fetch_format: :png),
                  status: :moved_permanently
    else
      render plain: "Image is being generated", status: :accepted
    end
  end

  # GET /statements/:id/square_dark
  # Redirect to inverted square image on Cloudinary
  def square_png_dark
    if @statement.square_image_public_id.present?
      redirect_to cl_image_path(@statement.square_image_public_id, effect: "negate", fetch_format: :png),
                  status: :moved_permanently
    else
      render plain: "Image is being generated", status: :accepted
    end
  end

  # GET /statements/:id/social
  # Redirect to social image (1200x630) on Cloudinary
  def social_jpg
    if @statement.social_image_public_id.present?
      redirect_to cl_image_path(@statement.social_image_public_id, fetch_format: :jpg, quality: 95),
                  status: :moved_permanently
    else
      render plain: "Image is being generated", status: :accepted
    end
  end

  # GET /statements/:id/social_dark
  # Redirect to inverted social image on Cloudinary
  def social_jpg_dark
    if @statement.social_image_public_id.present?
      redirect_to cl_image_path(@statement.social_image_public_id, effect: "negate", fetch_format: :jpg, quality: 95),
                  status: :moved_permanently
    else
      render plain: "Image is being generated", status: :accepted
    end
  end

  # GET /statements/:id/og_image
  # Serve the Facebook Open Graph image (1200x630) via Cloudinary
  def og_image
    if @statement.social_image_public_id.present?
      redirect_to cl_image_path(@statement.social_image_public_id, fetch_format: :png),
                  status: :moved_permanently
    else
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
end

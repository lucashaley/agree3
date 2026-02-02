class GenerateOgImageJob < ApplicationJob
  queue_as :default

  def perform(statement_id)
    statement = Statement.find(statement_id)

    # Generate both SVG formats
    square_svg = generate_svg_content_square(statement)
    social_svg = generate_svg_content_social(statement)

    # Upload square image (512x512) to Cloudinary
    square_result = Cloudinary::Uploader.upload(
      StringIO.new(square_svg),
      resource_type: "image",
      folder: "statements/square",
      public_id: "statement_#{statement_id}_square",
      format: "svg",
      overwrite: true
    )

    # Upload social image (1200x630) to Cloudinary
    social_result = Cloudinary::Uploader.upload(
      StringIO.new(social_svg),
      resource_type: "image",
      folder: "statements/social",
      public_id: "statement_#{statement_id}_social",
      format: "svg",
      overwrite: true
    )

    # Store public_ids in database
    statement.update!(
      square_image_public_id: square_result["public_id"],
      social_image_public_id: social_result["public_id"]
    )

    # Clean up old Active Storage attachment if exists
    statement.og_image.purge if statement.og_image.attached?

    Rails.logger.info "Images uploaded to Cloudinary for statement #{statement_id}"
    Rails.logger.info "  Square: #{square_result['public_id']}"
    Rails.logger.info "  Social: #{social_result['public_id']}"
  rescue => e
    Rails.logger.error "Failed to generate images for statement #{statement_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
  end

  private

  # Generate square SVG (512x512)
  def generate_svg_content_square(statement)
    size = 512
    padding = 40
    header = "we agree that..."
    content = statement.content
    content += "." unless content.end_with?(".", "!", "?")

    # Header dimensions
    header_size = 24
    header_line_height = header_size * 1.2
    header_total_height = header_line_height + 20

    # Available space for content
    available_width = size - (padding * 2)
    available_height = size - (padding * 2) - header_total_height

    # Calculate optimal font size
    content_size = calculate_optimal_font_size(content, available_width, available_height)

    # Light mode colors
    colors = {
      background: "#f8f9fa",
      text: "#111827",
      header: "#6b7280"
    }

    # Generate SVG
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{size}" height="#{size}" xmlns="http://www.w3.org/2000/svg">
        <rect width="#{size}" height="#{size}" fill="#{colors[:background]}"/>
        <text x="#{padding}" y="#{padding + header_size}"
              font-family="DejaVu Sans, sans-serif"
              font-size="#{header_size}"
              font-weight="700"
              fill="#{colors[:header]}"
              text-anchor="left">
          #{header}
        </text>
        <text x="#{padding}" y="#{padding + header_total_height + content_size}"
              font-family="DejaVu Sans, sans-serif"
              font-size="#{content_size}"
              font-weight="700"
              fill="#{colors[:text]}"
              text-anchor="left">
          #{wrap_text(content, available_width, content_size, padding)}
        </text>
      </svg>
    SVG
  end

  # Generate social SVG (1200x630)
  def generate_svg_content_social(statement)
    width = 1200
    height = 630
    padding = 60
    header = "we agree that..."
    content = statement.content
    content += "." unless content.end_with?(".", "!", "?")

    # Header dimensions
    header_size = 48
    header_line_height = header_size * 1.2
    header_total_height = header_line_height + 40

    # Available space for content
    available_width = width - (padding * 2)
    available_height = height - (padding * 2) - header_total_height

    # Calculate optimal font size
    content_size = calculate_optimal_font_size(content, available_width, available_height)

    # Light mode colors
    colors = {
      background: "#f8f9fa",
      text: "#111827",
      header: "#6b7280"
    }

    # Generate SVG
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="#{width}" height="#{height}" fill="#{colors[:background]}"/>
        <text x="#{padding}" y="#{padding + header_size}"
              font-family="DejaVu Sans, sans-serif"
              font-size="#{header_size}"
              font-weight="700"
              fill="#{colors[:header]}"
              text-anchor="left">
          #{header}
        </text>
        <text x="#{padding}" y="#{padding + header_total_height + content_size}"
              font-family="DejaVu Sans, sans-serif"
              font-size="#{content_size}"
              font-weight="700"
              fill="#{colors[:text]}"
              text-anchor="left">
          #{wrap_text(content, available_width, content_size, padding)}
        </text>
      </svg>
    SVG
  end

  def calculate_optimal_font_size(text, max_width, max_height)
    min_size = 16
    max_size = 120
    optimal_size = min_size

    max_size.downto(min_size) do |font_size|
      lines = wrap_text_to_lines(text, max_width, font_size)
      line_height = font_size * 1.2
      total_height = lines.length * line_height

      if total_height <= max_height
        optimal_size = font_size
        break
      end
    end

    optimal_size
  end

  def wrap_text_to_lines(text, max_width, font_size)
    words = text.split(" ")
    lines = []
    current_line = []

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

  def wrap_text(text, max_width, font_size, padding)
    lines = wrap_text_to_lines(text, max_width, font_size)

    lines.map.with_index do |line, i|
      %(<tspan x="#{padding}" dy="#{i == 0 ? 0 : font_size * 1.2}">#{line}</tspan>)
    end.join("\n          ")
  end
end

class GenerateOgImageJob < ApplicationJob
  queue_as :default

  def perform(statement_id)
    statement = Statement.find(statement_id)

    # Generate SVG content (1200x630 for Facebook)
    svg_content = generate_svg_content_og(statement)

    # Attach SVG directly to Active Storage
    # Cloudinary will handle transformations to PNG/JPG on-demand
    statement.og_image.attach(
      io: StringIO.new(svg_content),
      filename: "og_image.svg",
      content_type: "image/svg+xml"
    )

    Rails.logger.info "OG image SVG generated and attached for statement #{statement_id}"
  rescue => e
    Rails.logger.error "Failed to generate OG image for statement #{statement_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
  end

  private

  def generate_svg_content_og(statement)
    # Facebook Open Graph optimal dimensions
    width = 1200
    height = 630
    padding = 60

    # Prepare text
    header = "we agree that..."
    content = statement.content
    content += "." unless content.end_with?(".", "!", "?")

    # Calculate header dimensions
    header_size = 48
    header_line_height = header_size * 1.2
    header_total_height = header_line_height + 40 # header + spacing

    # Calculate available space for content
    available_width = width - (padding * 2)
    available_height = height - (padding * 2) - header_total_height

    # Calculate optimal font size that fills the space
    content_size = calculate_optimal_font_size(content, available_width, available_height)

    # Determine color scheme
    colors = {
      background: "#f8f9fa",
      text: "#111827",
      header: "#6b7280"
    }

    # Generate SVG for Facebook Open Graph
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="#{width}" height="#{height}" fill="#{colors[:background]}"/>
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

  def wrap_text(text, max_width, font_size)
    lines = wrap_text_to_lines(text, max_width, font_size)

    lines.map.with_index do |line, i|
      %(<tspan x="60" dy="#{i == 0 ? 0 : font_size * 1.2}">#{line}</tspan>)
    end.join("\n          ")
  end
end

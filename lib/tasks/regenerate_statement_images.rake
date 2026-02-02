namespace :statements do
  desc "Regenerate all statement images with new Cloudinary public_id approach"
  task regenerate_images: :environment do
    total = Statement.count
    regenerated = 0

    if total.zero?
      puts "No statements found."
      return
    end

    puts "Regenerating images for #{total} statements..."

    Statement.find_each.with_index do |statement, index|
      print "\rProcessing #{index + 1}/#{total}..."

      # Enqueue job with author context
      GenerateOgImageJob.perform_later(statement.id, statement.author_id)
      regenerated += 1

      # Throttle to avoid overwhelming Cloudinary API
      sleep 0.1
    end

    puts "\nEnqueued #{regenerated} image generation jobs"
    puts "Monitor job progress with: rails solid_queue:status"
  end
end

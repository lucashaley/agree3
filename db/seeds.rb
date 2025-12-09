# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data (optional - comment out if you want to keep existing data)
# Statement.destroy_all
# User.destroy_all

# Create a user if one doesn't exist
user = User.find_or_create_by!(email: "lucashaley@yahoo.com") do |u|
  u.password = "agrArmAd1ll0!"
  u.password_confirmation = "agrArmAd1ll0!"
end

puts "User: #{user.email}"

# Create root statements
root_statements = [
  "climate change is the most pressing issue of our time",
  "universal basic income would reduce poverty",
  "social media has made society more divided",
  "remote work is better than office work",
  "art created by AI can be considered real art",
  "space exploration should be a priority for humanity",
  "education should be free for everyone",
  "technology is making us less social",
  "democracy is the best form of government",
  "we should prioritize quality of life over economic growth"
]

created_roots = root_statements.map do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
  end
end

puts "Created #{created_roots.count} root statements"

# Create variants (descendants) for some statements
# Variants of "climate change is the most pressing issue of our time"
climate_variants = [
  "climate change requires immediate global action",
  "addressing climate change should be our top economic priority",
  "climate change is more urgent than any other environmental issue"
]

climate_variants.each do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
    s.parent = created_roots[0]
  end
end

# Create a second-level variant
climate_child = Statement.find_by(content: "climate change requires immediate global action")
if climate_child
  Statement.find_or_create_by!(content: "we need international cooperation to address climate change effectively") do |s|
    s.author = user
    s.parent = climate_child
  end
end

puts "Created climate change variants"

# Variants of "universal basic income would reduce poverty"
ubi_variants = [
  "universal basic income would eliminate the need for welfare programs",
  "a monthly basic income would provide financial security for all citizens",
  "guaranteed income would reduce poverty more effectively than current programs"
]

ubi_variants.each do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
    s.parent = created_roots[1]
  end
end

puts "Created UBI variants"

# Variants of "social media has made society more divided"
social_media_variants = [
  "social media algorithms amplify divisive content",
  "online platforms have created echo chambers that divide us",
  "social media has reduced civil discourse in society"
]

social_media_variants.each do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
    s.parent = created_roots[2]
  end
end

# Create a nested variant
social_media_child = Statement.find_by(content: "social media algorithms amplify divisive content")
if social_media_child
  Statement.find_or_create_by!(content: "recommendation algorithms prioritize engagement over truth") do |s|
    s.author = user
    s.parent = social_media_child
  end
end

puts "Created social media variants"

# Variants of "remote work is better than office work"
remote_work_variants = [
  "working from home increases productivity and work-life balance",
  "remote work eliminates commute time and reduces stress"
]

remote_work_variants.each do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
    s.parent = created_roots[3]
  end
end

puts "Created remote work variants"

# Variants of "education should be free for everyone"
education_variants = [
  "free higher education would reduce income inequality",
  "access to education should be a fundamental human right",
  "publicly funded education benefits society as a whole"
]

education_variants.each do |content|
  Statement.find_or_create_by!(content: content) do |s|
    s.author = user
    s.parent = created_roots[6]
  end
end

puts "Created education variants"

total_count = Statement.count
puts "\n✓ Seeding complete!"
puts "Total statements: #{total_count}"
puts "Root statements: #{Statement.where(parent_id: nil).count}"
puts "Variant statements: #{Statement.where.not(parent_id: nil).count}"

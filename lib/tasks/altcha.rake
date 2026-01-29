namespace :altcha do
  desc "Clean up expired ALTCHA solutions"
  task cleanup: :environment do
    deleted_count = AltchaSolution.cleanup
    puts "Deleted #{deleted_count} expired ALTCHA solutions"
  end
end

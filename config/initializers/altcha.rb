# frozen_string_literal: true

Altcha.setup do |config|
  config.algorithm = 'SHA-256'
  config.num_range = (50_000..500_000)  # 2-5 seconds solve time
  config.timeout = 5.minutes
  config.hmac_key = ENV['ALTCHA_HMAC_KEY'] || Rails.application.credentials.dig(:altcha, :hmac_key) || 'f3de8ed7170c113ebc84d115cf7da231f2770533ba45c60e51f608a438fa796a'
end
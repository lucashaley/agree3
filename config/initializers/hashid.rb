Hashid::Rails.configure do |config|
  # Salt for generating hashids - change this to a unique value for your app
  config.salt = "agree3_statement_hashid_salt"

  # Minimum length of hashids (optional)
  config.min_hash_length = 6

  # Alphabet to use for hashids (optional)
  # config.alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
end

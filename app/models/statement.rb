class Statement < ApplicationRecord
  acts_as_tree order: "created_at"
  has_closure_tree
  acts_as_votable

  belongs_to :author, class_name: "User"

  validates :content, presence: true

  # Get all ancestors by walking up the parent chain
  def all_ancestors
    result = []
    current = self.parent
    while current
      result << current
      current = current.parent
    end
    result
  end

  # Recursively count all descendants (children and their children, etc.)
  def descendant_count
    children.sum { |child| 1 + child.descendant_count }
  end

  # Get all descendants recursively
  def all_descendants
    children.flat_map { |child| [ child ] + child.all_descendants }
  end

  normalizes :content, with: -> do
    text = _1.sub(/\.\z/, "") # Remove trailing period

    # Lowercase first letter unless it's a proper noun
    words = text.split(/\s+/)
    if words.any?
      first_word = words[0]

      # List of common proper nouns and words that should stay capitalized
      proper_nouns = %w[
        I January February March April May June July August September October November December
        Monday Tuesday Wednesday Thursday Friday Saturday Sunday
        America American Asia Asian Europe European Africa African
        Australia Australian Canada Canadian Mexico Mexican
        God Allah Buddha Jesus Christ Muhammad
        English Spanish French German Chinese Japanese
      ]

      # Keep capitalization if:
      # - It's an acronym (all caps, 2+ letters)
      # - It's in our proper noun list
      # Otherwise, lowercase the first letter
      unless (first_word.length > 1 && first_word == first_word.upcase) || proper_nouns.include?(first_word)
        first_word = first_word[0].downcase + first_word[1..-1] if first_word.length > 0
        words[0] = first_word
        text = words.join(" ")
      end
    end

    text
  end
end

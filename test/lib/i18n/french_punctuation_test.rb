# frozen_string_literal: true

require "test_helper"
require "yaml"

class FrenchPunctuationTest < ActiveSupport::TestCase
  SPACED_DOUBLE_PUNCTUATION = /[ \u00A0\u202F](?:[:;?]|!(?!\[))/

  test "French locale values follow Swiss punctuation" do
    violations = locale_files.flat_map do |file|
      french_values(YAML.safe_load_file(file, aliases: true)).filter_map do |key, value|
        violation(file, key, value) if value.match?(SPACED_DOUBLE_PUNCTUATION)
      end
    end

    assert_empty violations, violations.join("\n")
  end

  test "French handbook and update copy follows Swiss punctuation" do
    violations = french_content_files.flat_map { |file| content_violations(file) }

    assert_empty violations, violations.join("\n")
  end

  private

  def locale_files
    Dir[Rails.root.join("config/locales/**/*.{yml,yaml}")]
  end

  def french_content_files
    Dir[Rails.root.join("app/views/**/*.fr.md.erb")]
  end

  def french_values(value, path = [])
    return [] unless value.is_a?(Hash)

    value.flat_map do |key, nested|
      key.to_s == "_fr" ? [ [ path.join("."), nested.to_s ] ] : french_values(nested, [ *path, key ])
    end
  end

  def content_violations(file)
    in_fence = false

    File.readlines(file).each_with_index.filter_map do |line, index|
      if line.lstrip.match?(/\A(?:```|~~~)/)
        in_fence = !in_fence
        next
      end
      next if in_fence

      text = line.gsub(/<%.*?%>/, "CODE").gsub(/`[^`]*`/, "CODE").gsub("![", "IMAGE[")
      violation(file, index + 1, text) if text.match?(SPACED_DOUBLE_PUNCTUATION)
    end
  end

  def violation(file, location, value)
    "#{Pathname.new(file).relative_path_from(Rails.root)}:#{location}: #{value.strip}"
  end
end

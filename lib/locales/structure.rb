# frozen_string_literal: true

require "yaml"

module Locales
  module Structure
    INTERPOLATION_TOKEN = /%\{([^}]+)\}/
    LIQUID_OUTPUT_TOKEN = /\{\{\s*([^}|]+?)(?:\s*\|[^}]*)?\s*\}\}/
    INVALID_LINE_BREAK = %r{</br\s*>}i
    GERMAN_SHARP_S = /ß/
    TYPOGRAPHIC_DOUBLE_QUOTES = /[«»„“”]/
    PLURAL_KEYS = %w[zero one two few many other].freeze
    US_ENGLISH_SPELLING = {
      /\bcancelled\b/i => "use canceled, not cancelled",
      /\bcancelation\b/i => "use cancellation, not cancelation"
    }.freeze

    module_function

    def locale_files(root: Rails.root)
      Dir[root.join("config/locales/**/*.{yml,yaml}")].sort
    end

    def view_files(root: Rails.root)
      Dir[root.join("app/views/**/*.erb")].sort
    end

    def load_translations(files)
      files.each_with_object({}) do |file, translations|
        translations.deep_merge!(YAML.load_file(file))
      end
    end

    def typographic_quote_violations(files)
      files.flat_map do |file|
        File.readlines(file).each_with_index.filter_map do |line, index|
          "#{file}:#{index + 1}: use straight double quotes, not typographic quotes" if line.match?(TYPOGRAPHIC_DOUBLE_QUOTES)
        end
      end
    end

    def duplicate_leaf_violations(files)
      seen = {}
      source_violations = files.flat_map { |file| duplicate_mapping_violations(file) }
      cross_file_violations = files.flat_map do |file|
        leaf_paths(YAML.load_file(file)).filter_map do |path|
          if previous_file = seen[path]
            "#{path_without_root(path)}: duplicate locale leaf in #{previous_file} and #{file}"
          else
            seen[path] = file
            nil
          end
        end
      end

      source_violations + cross_file_violations
    end

    def violations(translations, locales: I18n.available_locales, basket_scopes: Organization.basket_i18n_scopes, activity_scopes: Organization.activity_i18n_scopes)
      groups = translation_groups(translations, locale_keys: locales.map { |locale| "_#{locale}" })

      interpolation_violations(groups) +
        content_violations(groups) +
        invalid_scoped_path_violations(groups, basket_scopes, activity_scopes) +
        misplaced_html_scope_violations(groups, basket_scopes + activity_scopes) +
        scope_matrix_violations(groups, basket_scopes, activity_scopes)
    end

    def translation_groups(value, path = [], locale_keys:, groups: [])
      return groups unless value.is_a?(Hash)

      translations = value.slice(*locale_keys)
      groups << [ path, translations ] if translations.any?

      value.each do |key, nested|
        next if key.to_s.in?(locale_keys)

        translation_groups(nested, [ *path, key ], locale_keys:, groups:)
      end

      groups
    end

    def interpolation_violations(groups)
      groups.flat_map do |path, translations|
        english = translations["_en"]
        next [] unless english.is_a?(String)

        expected = interpolation_tokens(english)
        expected_liquid = liquid_output_tokens(english)

        translations.flat_map do |locale, value|
          next [] unless locale != "_en" && value.is_a?(String)

          location = translation_path(path, locale)
          violations = []
          actual = interpolation_tokens(value)
          actual_liquid = liquid_output_tokens(value)

          if actual != expected
            violations << "#{location}: interpolation tokens #{format_tokens(actual)} do not match English #{format_tokens(expected)}"
          end
          if actual_liquid != expected_liquid
            violations << "#{location}: Liquid output tokens #{format_liquid_tokens(actual_liquid)} do not match English #{format_liquid_tokens(expected_liquid)}"
          end
          violations
        end
      end
    end

    def content_violations(groups)
      groups.flat_map do |path, translations|
        translations.flat_map do |locale, value|
          value.is_a?(String) ? content_violations_for(path, locale, value) : []
        end
      end
    end

    def content_violations_for(path, locale, value)
      location = translation_path(path, locale)
      violations = []
      violations << "#{location}: invalid </br>; use <br> or <br/>" if value.match?(INVALID_LINE_BREAK)
      violations << "#{location}: use straight double quotes, not typographic quotes" if value.match?(TYPOGRAPHIC_DOUBLE_QUOTES)
      violations << "#{location}: Swiss German uses ss, not ß" if locale == "_de" && value.match?(GERMAN_SHARP_S)

      US_ENGLISH_SPELLING.each do |pattern, message|
        violations << "#{location}: #{message}" if locale == "_en" && value.match?(pattern)
      end

      violations
    end

    def invalid_scoped_path_violations(groups, basket_scopes, activity_scopes)
      valid_scopes = { basket: basket_scopes, activity: activity_scopes }

      groups.filter_map do |path, _|
        index = path.each_index.find { |candidate| scoped_key(path[candidate], valid_scopes) }
        next unless index
        next if valid_scoped_index?(path, index)

        "#{path_without_root(path)}: scope must be on the translation key or directly above a plural branch"
      end
    end

    def misplaced_html_scope_violations(groups, scopes)
      scope_pattern = Regexp.union(scopes)

      groups.flat_map do |path, _|
        path.filter_map do |key|
          match = key.to_s.match(/\A(?<base>.+)_html\/(?<scope>#{scope_pattern})\z/)
          next unless match

          "#{path_without_root(path)}: scope must precede _html (use #{match[:base]}/#{match[:scope]}_html)"
        end
      end
    end

    def scope_matrix_violations(groups, basket_scopes, activity_scopes)
      valid_scopes = { basket: basket_scopes, activity: activity_scopes }
      base_paths = groups.map { |path, _| path_without_root(path) }
      families = Hash.new { |hash, key| hash[key] = [] }

      groups.each do |path, _|
        scoped_path = scoped_path(path, valid_scopes)
        next unless scoped_path

        families[[ scoped_path.fetch(:base), scoped_path.fetch(:kind) ]] << scoped_path.fetch(:scope)
      end

      families.filter_map do |(path, kind), scopes|
        next if path.in?(base_paths)

        missing_scopes = valid_scopes.fetch(kind) - scopes.uniq
        next if missing_scopes.empty?

        "#{path}: missing #{kind} scopes: #{missing_scopes.join(", ")} (add an unscoped fallback or all #{kind} scopes)"
      end
    end

    def scoped_path(path, valid_scopes)
      scoped_indices(path).each do |index|
        scoped_key = scoped_key(path[index], valid_scopes)
        next unless scoped_key

        base_path = path.dup
        base_path[index] = scoped_key.fetch(:base)
        return scoped_key.merge(base: path_without_root(base_path))
      end

      nil
    end

    def scoped_indices(path)
      indices = [ path.length - 1 ]
      indices << path.length - 2 if path.length > 1 && path.last.to_s.in?(PLURAL_KEYS)
      indices
    end

    def valid_scoped_index?(path, index)
      index == path.length - 1 ||
        (index == path.length - 2 && path.last.to_s.in?(PLURAL_KEYS))
    end

    def scoped_key(key, valid_scopes)
      scope = valid_scopes.values.flatten.find { |value| key.to_s.end_with?("/#{value}") || key.to_s.end_with?("/#{value}_html") }
      return unless scope

      kind = valid_scopes.find { |_, values| scope.in?(values) }.first
      match = key.to_s.match(/\A(?<base>.+)\/#{Regexp.escape(scope)}(?<html>_html)?\z/)
      return unless match

      { base: "#{match[:base]}#{match[:html]}", kind:, scope: }
    end

    def interpolation_tokens(value)
      value.scan(INTERPOLATION_TOKEN).flatten.tally
    end

    def liquid_output_tokens(value)
      value.scan(LIQUID_OUTPUT_TOKEN).flatten.map(&:strip).tally
    end

    def leaf_paths(value, path = [])
      return [ path ] unless value.is_a?(Hash)

      value.flat_map { |key, nested| leaf_paths(nested, [ *path, key ]) }
    end

    def duplicate_mapping_violations(file)
      duplicate_mapping_violations_for(Psych.parse_file(file).root, file, [])
    end

    def duplicate_mapping_violations_for(node, file, path)
      case node
      when Psych::Nodes::Mapping
        duplicate_mapping_violations_in_mapping(node, file, path)
      when Psych::Nodes::Sequence
        node.children.each_with_index.flat_map do |child, index|
          duplicate_mapping_violations_for(child, file, [ *path, index ])
        end
      else
        []
      end
    end

    def duplicate_mapping_violations_in_mapping(node, file, path)
      seen = {}

      node.children.each_slice(2).flat_map do |key_node, value_node|
        key = key_node.value
        current_path = [ *path, key ]
        violations = if first_line = seen[key]
          [ "#{file}:#{key_node.start_line + 1}: duplicate YAML key #{path_without_root(current_path)} (first defined at line #{first_line})" ]
        else
          seen[key] = key_node.start_line + 1
          []
        end

        violations + duplicate_mapping_violations_for(value_node, file, current_path)
      end
    end

    def format_tokens(tokens)
      return "none" if tokens.empty?

      tokens.sort.map { |token, count| count == 1 ? "%{#{token}}" : "%{#{token}} × #{count}" }.join(", ")
    end

    def format_liquid_tokens(tokens)
      return "none" if tokens.empty?

      tokens.sort.map { |token, count| count == 1 ? "{{ #{token} }}" : "{{ #{token} }} × #{count}" }.join(", ")
    end

    def translation_path(path, locale)
      "#{path_without_root(path)}.#{locale}"
    end

    def path_without_root(path)
      path.reject { |key| key == "_" }.join(".")
    end
  end
end

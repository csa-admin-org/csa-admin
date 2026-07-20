# frozen_string_literal: true

module Locales
  # Full locales:check pipeline without booting Rails.
  module Checker
    module_function

    def check!
      missing!
      structure!
      verify!
    end

    def missing!
      translations = Catalog.load_from_config
      all_keys = translations.flat_map { |_, keys| Catalog.list_all_keys(keys) }.uniq.compact
      missing = []

      translations.each do |locale, keys|
        absent = (all_keys - Catalog.list_all_keys(keys)).uniq
        next if absent.empty?

        missing << [ locale, absent ]
      end

      return if missing.empty?

      missing.each do |locale, keys|
        keys.each do |key|
          english = Catalog.lookup(translations["en"], key)
          puts "#{key}:"
          puts "  _en: #{english}"
          puts "  _#{locale}: ???"
        end
      end
      exit 1
    end

    def structure!
      locale_files = Structure.locale_files
      violations = Structure.duplicate_leaf_violations(locale_files) +
        Structure.violations(Structure.load_translations(locale_files)) +
        Structure.typographic_quote_violations(Structure.view_files)

      return if violations.empty?

      puts "Locales did not pass structure verification."
      violations.each { |violation| puts "  #{violation}" }
      exit 1
    end

    def verify!
      locale_files = Structure.locale_files
      before = locale_files.to_h { |file| [ file, File.read(file) ] }

      # Always restore: check must not leave reformatted files (or a partial write).
      changed = begin
        Catalog.convert_and_write(Catalog.load_from_config)
        locale_files.select { |file| File.read(file) != before[file] }
      ensure
        before.each { |file, content| File.write(file, content) }
      end

      return if changed.empty?

      puts "Locales did not pass format verification."
      puts "Run `bin/locales format` and inspect the diff."
      changed.each { |file| puts "  #{file}" }
      exit 1
    end
  end
end

# frozen_string_literal: true

module Locales
  # Read/write helpers for the side-by-side locale YAML format.
  # No Rails required.
  module Catalog
    module_function

    def format!
      convert_and_write(load_from_config)
    end

    def load_from_config
      translations = Structure.load_translations(Structure.locale_files)
      LOCALES.each_with_object({}) do |locale, hash|
        Locales.deep_merge!(hash, convert_to_standard(translations, locale.to_s))
      end
    end

    def convert_and_write(translations)
      converted = LOCALES.each_with_object({}) do |locale, hash|
        Locales.deep_merge!(hash, convert(translations[locale.to_s], "_#{locale}"))
      end
      write_to_config(converted)
    end

    def convert_to_standard(value, locale)
      if value.key?("_")
        { locale => convert_to_standard(value["_"], locale) }
      elsif value.key?("_#{locale}")
        value["_#{locale}"]
      elsif !value.keys.all? { |k| k.start_with?("_") }
        value.to_h { |k, v| [ k, convert_to_standard(v, locale) ] }
      end
    end

    def convert(value, locale)
      if value.is_a?(Hash)
        value.to_h { |k, v| [ k, convert(v, locale) ] }
          .delete_if { |_, v| v.nil? }
      else
        { locale => value } if value
      end
    end

    def write_to_config(translations)
      translations.each do |key, value|
        name = File.basename(key.to_s)
        raise ArgumentError, "invalid locale file key: #{key.inspect}" if name.empty? || name != key.to_s

        write_yaml(Locales.root.join("config/locales/#{name}.yml"), "_" => { name => value })
      end
    end

    def write_yaml(file_name, data)
      content = deep_sort_hash(data).to_yaml(line_width: -1).lines[1..].join
      File.write(file_name, content)
    end

    def deep_sort_hash(hash)
      if hash.keys.all? { |k| k.start_with?("_") }
        locales_order = LOCALES.map { |locale| "_#{locale}" }
        sorted_keys = hash.keys.sort_by { |k| locales_order.index(k) || locales_order.size }
      else
        sorted_keys = hash.keys.sort
      end
      sorted_keys.to_h { |k|
        [ k, hash[k].is_a?(Hash) ? deep_sort_hash(hash[k]) : hash[k] ]
      }
    end

    def list_all_keys(value, key = nil)
      if value.is_a?(Hash)
        value.flat_map do |k, v|
          list_all_keys(v, [ key, k ].compact.join(".")) if v
        end
      else
        key
      end
    end

    def lookup(hash, key)
      key.split(".").reduce(hash) { |node, part|
        break unless node.is_a?(Hash)

        node[part]
      }
    end
  end
end

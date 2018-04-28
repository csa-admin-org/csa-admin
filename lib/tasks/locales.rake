namespace :locales do
  desc 'Automatically format the locale files'
  task format: :environment do
    convert_and_write_to_config(load_translations_from_config)
  end

  desc 'Verify that locale files adhere to the automatic format'
  task verify: :format do
    if `git status --short --porcelain -- config/locales`.empty?
      puts 'Locales passed format verification.'
    else
      puts 'Locales did not pass format verification.'
      puts 'Run `rails locales:format` and inspect the diff.'
      exit 1
    end
  end

  def filter_additional_keys!(hash, reference)
    hash.each do |key, value|
      if reference[key]
        filter_additional_keys!(value, reference[key]) if value.is_a?(Hash)
      else
        hash.delete(key)
      end
    end
  end

  def load_translations_from_config
    translations = {}
    Dir['config/locales/**/*.yml'].each do |file|
      translations.deep_merge!(YAML.load_file(file))
    end
    used_locales.each_with_object({}) do |locale, h|
      h.deep_merge!(convert_to_standard(translations, locale.to_s))
    end
  end

  def load_translations_from_tmp
    translations = {}
    Dir['tmp/locales/*.yml'].each do |file|
      translations.deep_merge!(YAML.load_file(file))
    end
    translations
  end

  def convert_and_write_to_config(translations)
    translations = used_locales.each_with_object({}) do |locale, h|
      convert(translations[locale.to_s], "_#{locale}")
      h.deep_merge!(convert(translations[locale.to_s], "_#{locale}"))
    end
    write_to_config_locales(translations)
  end

  def convert_to_standard(value, locale)
    if value.key?('_')
      { locale => convert_to_standard(value['_'], locale) }
    elsif value.key?("_#{locale}")
      value["_#{locale}"]
    elsif !value.keys.all? { |k| k.start_with?('_') }
      value.map { |k, v| [k, convert_to_standard(v, locale)] }.to_h
    end
  end

  def convert(value, locale)
    if value.is_a?(Hash)
      value.map { |k, v| [k, convert(v, locale)] }
        .to_h
        .delete_if { |_, v| v.nil? }
    else
      { locale => value } if value
    end
  end

  def write_to_tmp_locales(translations)
    clear_tmp_locales!
    translations.each do |locale, hash|
      write_yaml("tmp/locales/#{locale}.yml", locale => hash)
    end
  end

  def write_to_config_locales(translations)
    translations.each do |key, value|
      write_yaml("config/locales/#{key}.yml", '_' => { key => value })
    end
  end

  def clear_tmp_locales!
    FileUtils.remove_dir('tmp/locales', true)
    FileUtils.mkdir_p('tmp/locales')
  end

  def write_yaml(file_name, data)
    content = deep_sort_hash(data).to_yaml(line_width: -1).lines[1..-1].join
    File.write(file_name, content)
  end

  def deep_sort_hash(hash)
    hash.sort.map { |k, v| [k, v.is_a?(Hash) ? deep_sort_hash(v) : v] }.to_h
  end

  def used_locales
    I18n.available_locales.sort - [:en]
  end
end

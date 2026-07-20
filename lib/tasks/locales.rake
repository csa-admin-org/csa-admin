# frozen_string_literal: true

require "uri"
require "cgi"
require "locales"

namespace :locales do
  desc "Automatically format the locale files"
  task format: :environment do
    Locales::Catalog.format!
  end

  desc "Check that locales format is correct and that no keys are missing"
  task check: :environment do
    Locales::Checker.check!
  end

  desc "Check locale interpolation, scoped keys, and markup"
  task structure: :environment do
    Locales::Checker.structure!
  end

  desc "Verify that locale files adhere to the automatic format"
  task verify: :environment do
    Locales::Checker.verify!
  end

  desc "Open an URL in all available locales"
  task open: :environment do
    url = ENV["URL"]
    raise "URL is required" unless url

    Locales::LOCALES.each do |locale|
      uri = URI.parse(URI::DEFAULT_PARSER.escape(url))
      params = CGI.parse(uri.query || "")
      params["locale"] = [ locale.to_s ]
      uri.query = URI.encode_www_form(params)
      system("open -a 'Safari' '#{uri}'")
    end
  end

  desc "List all keys missing a translation"
  task missing: :environment do
    Locales::Checker.missing!
  end
end

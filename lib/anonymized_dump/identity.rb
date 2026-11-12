# frozen_string_literal: true

require "digest"

module AnonymizedDump
  # Deterministic stand-ins. The seed is the tenant salt plus the row id, so
  # the same member keeps the same fake name if the job runs twice, and a
  # billing name does not collide with the member name.
  class Identity
    PLACES = {
      "CH" => {
        "de" => [ %w[8001 Zürich], %w[3000 Bern], %w[4001 Basel], %w[9000 St. Gallen], %w[6003 Luzern] ],
        "fr" => [ %w[1000 Lausanne], %w[1201 Genève], %w[2000 Neuchâtel], %w[1700 Fribourg], %w[1950 Sion] ],
        "it" => [ %w[6900 Lugano], %w[6500 Bellinzona], %w[6600 Locarno] ],
        "en" => [ %w[8001 Zurich], %w[1201 Geneva], %w[3000 Bern] ]
      },
      "DE" => {
        "de" => [ %w[10115 Berlin], %w[80331 München], %w[50667 Köln], %w[20095 Hamburg], %w[70173 Stuttgart] ]
      },
      "FR" => {
        "fr" => [ %w[75001 Paris], %w[69001 Lyon], %w[13001 Marseille], %w[31000 Toulouse] ]
      },
      "NL" => {
        "nl" => [ [ "1012 JS", "Amsterdam" ], [ "3011 AD", "Rotterdam" ], [ "3511 LX", "Utrecht" ], [ "2511 CV", "Den Haag" ] ]
      }
    }.freeze

    Place = Struct.new(:zip, :city)

    def initialize(salt:, domain: DISPOSABLE_EMAIL_DOMAIN)
      @salt = salt
      @domain = domain
    end

    def person_name(table, id, column, locale)
      with_faker(seed_for(table, id, column), locale) {
        "#{Faker::Name.first_name} #{Faker::Name.last_name}"
      }
    end

    def street(table, id, column, locale)
      with_faker(seed_for(table, id, column), locale) {
        Faker::Address.street_address.to_s.delete("\n")[0, 240]
      }
    end

    def place(table, id, scope, locale, country)
      choices = place_list(country, locale)
      zip, city = choices.fetch(seed_for(table, id, scope) % choices.size)
      Place.new(zip, city)
    end

    def emails(name, id, count)
      count.times.map { |index| email_address(name, id, index) }.join(", ")
    end

    def email_address(name, id, index = 0)
      local = index.zero? ? "#{slug(name)}.#{id}" : "#{slug(name)}.#{id}.#{index + 1}"
      "#{local}@#{@domain}"
    end

    def phone(country:, seed:)
      case country.to_s.upcase
      when "DE" then format("+49151%08d", seed % 100_000_000)
      when "NL" then format("+316%08d", seed % 100_000_000)
      when "FR" then format("+336%08d", seed % 100_000_000)
      else format("+4179%07d", seed % 10_000_000)
      end
    end

    def token(table, id, column)
      digest = Digest::SHA256.hexdigest(seed_key(table, id, column))
      "ANON#{digest[0, 31]}"
    end

    def card_number(table, id, column)
      format("%016d", seed_for(table, id, column) % (10**16))
    end

    def seed_for(*parts)
      Digest::SHA256.hexdigest(seed_key(*parts))[0, 8].to_i(16)
    end

    private

    def seed_key(*parts)
      [ @salt, *parts ].join("\u0000")
    end

    def slug(name)
      transliterated = I18n.transliterate(name.to_s).downcase
      cleaned = transliterated.gsub(/[^a-z0-9]+/, ".").gsub(/\A\.|\.\z/, "")
      cleaned.presence || "person"
    end

    def place_list(country, locale)
      country_places = PLACES[country.to_s.upcase] || PLACES["CH"]
      country_places[locale.to_s] || country_places.values.first || PLACES["CH"]["en"]
    end

    def with_faker(seed, locale)
      require "faker"
      previous_locale = Faker::Config.locale
      previous_random = Faker::Config.random
      Faker::Config.locale = faker_locale(locale)
      Faker::Config.random = Random.new(seed)
      yield
    ensure
      if defined?(Faker::Config)
        Faker::Config.locale = previous_locale
        Faker::Config.random = previous_random
      end
    end

    def faker_locale(locale)
      code = locale.to_s.split("-").first
      code.presence || "en"
    end
  end
end

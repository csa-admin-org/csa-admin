# frozen_string_literal: true

require "yaml"

module AnonymizedDump
  # config/anonymized_dump.yml is the allowlist. Load fails when db/schema.rb
  # has a column the file does not name, or the file names a column that is gone.
  class Classification
    PATH = Rails.root.join("config/anonymized_dump.yml")
    RULES = %w[
      keep clear set_false empty_object empty_array drop
      person_name emails email phone street zip city iban token card_number
      encrypt_null encrypt_empty encrypt_placeholder
    ].freeze
    BULK_RULES = %w[clear encrypt_null set_false empty_object empty_array].freeze
    FAKE_RULES = %w[person_name emails email phone street zip city iban token card_number].freeze
    TEXT_TYPES = %w[string text json].freeze

    Diff = Struct.new(:missing, :extra, keyword_init: true)

    def self.load(path = PATH, schema: SchemaColumns.parse)
      new(YAML.safe_load_file(path), schema: schema).tap(&:validate!)
    end

    def initialize(data, schema:)
      @data = data
      @schema = schema
    end

    def rule(table, column)
      tables.dig(table, "rules", column)
    end

    def drop_order
      Array(@data.fetch("drop_order"))
    end

    def drop_tables
      tables.filter_map { |name, spec| name if spec["action"] == "drop" }
    end

    def purge_rich_text_record_types
      Array(@data.fetch("purge_rich_text_record_types"))
    end

    def allowed_email_domain
      @data.fetch("allowed_email_domain")
    end

    def placeholder_api_token
      @data.fetch("placeholder_api_token")
    end

    def seed_salt
      @data.fetch("seed_salt")
    end

    def retention_days
      @data.fetch("retention_days")
    end

    def email_policy(table, column)
      key = "#{table}.#{column}"
      return "allow" if allow_emails.include?(key)
      return "disposable" if disposable_emails.include?(key)

      column_spec = @schema[table]&.columns&.find { |item| item.name == column }
      return if column_spec.nil? || column_spec.virtual
      return if drop_tables.include?(table)
      return unless TEXT_TYPES.include?(column_spec.type)

      "forbid"
    end

    def each_rule
      tables.each do |table, spec|
        spec.fetch("rules").each do |column, rule|
          yield table, column, rule
        end
      end
    end

    def diff(schema_names)
      missing = []
      extra = []
      schema_names.each do |table, columns|
        columns.each do |column|
          missing << "#{table}.#{column}" if rule(table, column).nil?
        end
      end
      each_rule do |table, column, _rule|
        extra << "#{table}.#{column}" unless schema_names[table]&.include?(column)
      end
      Diff.new(missing: missing, extra: extra)
    end

    def validate!
      raise Error, "anonymized dump config must be a mapping" unless @data.is_a?(Hash)

      unknown = rules_used - RULES
      raise Error, "unknown anonymized dump rules: #{unknown.join(", ")}" if unknown.any?

      coverage = diff(@schema.names)
      if coverage.missing.any? || coverage.extra.any?
        raise Error, <<~MSG.squish
          anonymized dump classification does not match db/schema.rb
          (missing: #{coverage.missing.join(", ")}; extra: #{coverage.extra.join(", ")})
        MSG
      end

      validate_drop_tables!
      validate_nullability!
      validate_email_policy!
    end

    private

    def tables
      @data.fetch("tables")
    end

    def allow_emails
      Array(@data.dig("email_policy", "allow"))
    end

    def disposable_emails
      Array(@data.dig("email_policy", "disposable"))
    end

    def rules_used
      tables.flat_map { |_name, spec| spec.fetch("rules").values }.uniq
    end

    def validate_drop_tables!
      unless drop_order.uniq.size == drop_order.size
        raise Error, "drop_order lists a table twice"
      end

      unless drop_order.sort == drop_tables.sort
        raise Error, "drop_order #{drop_order.sort} does not match drop tables #{drop_tables.sort}"
      end

      each_rule do |table, column, rule|
        dropped = drop_tables.include?(table)
        if dropped && rule != "drop"
          raise Error, "#{table}.#{column} is #{rule} on a dropped table"
        elsif !dropped && rule == "drop"
          raise Error, "#{table}.#{column} is drop but #{table} is kept"
        end
      end
    end

    def validate_nullability!
      each_rule do |table, column, rule|
        next unless rule == "clear" || rule == "encrypt_null"

        column_spec = @schema[table].columns.find { |item| item.name == column }
        unless column_spec.null
          raise Error, "#{table}.#{column} is NOT NULL and cannot use #{rule}"
        end
      end
    end

    def validate_email_policy!
      each_rule do |table, column, rule|
        next unless rule == "email" || rule == "emails"

        key = "#{table}.#{column}"
        unless disposable_emails.include?(key)
          raise Error, "#{key} is faked to a disposable address but is not in email_policy.disposable"
        end
      end

      (allow_emails + disposable_emails).each do |key|
        table, column = key.split(".", 2)
        raise Error, "email policy names unknown column #{key}" if rule(table, column).nil?
      end
    end
  end
end

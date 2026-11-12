# frozen_string_literal: true

require "json"

module AnonymizedDump
  # Rewrites the current tenant database in place. Replica restore and bucket
  # upload stay outside this class. Encrypted columns are overwritten with
  # ciphertext from the key of this process (the dev key agents already boot
  # with). Existing production ciphertext is never decrypted.
  class Anonymizer
    BILLING_COLUMNS = %w[billing_name billing_street billing_city billing_zip].freeze

    def self.call(reindex: false, vacuum: false)
      guard!
      ActiveRecord::Base.connection.transaction do
        new.run
        SearchEntry.delete_all
        SearchEntry.rebuild! if reindex
      end
      vacuum! if vacuum
    end

    def self.guard!
      raise Error, "Refusing to anonymize in production" if Rails.env.production?
      raise Error, "Refusing to anonymize outside a tenant" if Tenant.outside?
    end

    def self.vacuum!
      ActiveRecord::Base.connection.execute("VACUUM")
    end

    def initialize(classification = Classification.load)
      @classification = classification
      @schema = SchemaColumns.parse
      @identity = Identity.new(salt: classification.seed_salt, domain: classification.allowed_email_domain)
    end

    def run
      bulk_clear!
      delete_dropped!
      purge_rich_text!
      fake_tables!
      scrub_text!
      encrypt!
    end

    private

    def bulk_clear!
      grouped = Hash.new { |hash, key| hash[key] = [] }
      @classification.each_rule do |table, column, rule|
        next unless Classification::BULK_RULES.include?(rule)

        grouped[table] << assignment(column, rule)
      end
      grouped.each do |table, assignments|
        execute("UPDATE #{qtable(table)} SET #{assignments.join(", ")}")
      end
    end

    def assignment(column, rule)
      quoted = qcol(column)
      case rule
      when "clear", "encrypt_null" then "#{quoted} = NULL"
      when "set_false" then "#{quoted} = 0"
      when "empty_object" then "#{quoted} = '{}'"
      when "empty_array" then "#{quoted} = '[]'"
      else raise Error, "unexpected bulk rule #{rule}"
      end
    end

    def delete_dropped!
      @classification.drop_order.each do |table|
        execute("DELETE FROM #{qtable(table)}")
      end
    end

    def purge_rich_text!
      types = @classification.purge_rich_text_record_types
      return if types.empty?

      quoted = types.map { |type| connection.quote(type) }.join(", ")
      execute(<<~SQL.squish)
        DELETE FROM #{qtable("action_text_rich_texts")}
        WHERE #{qcol("record_type")} IN (#{quoted})
      SQL
    end

    def fake_tables!
      grouped = Hash.new { |hash, key| hash[key] = {} }
      @classification.each_rule do |table, column, rule|
        grouped[table][column] = rule if Classification::FAKE_RULES.include?(rule)
      end
      grouped.each { |table, rules| fake_table(table, rules) }
    end

    def fake_table(table, rules)
      select_rows(table, rules.keys).each do |row|
        attrs = fake_attributes(table, row, rules)
        update_row(table, row["id"], attrs)
      end
    end

    def fake_attributes(table, row, rules)
      attrs = {}
      anonymized = anonymized_row?(table, row)
      locale = locale_for(row)
      country = country_for(row)
      partial = partial_billing_columns(table, row)
      partial.each { |column| attrs[column] = nil }

      rules.each do |column, rule|
        next unless rule == "person_name"
        next if partial.include?(column)
        next if skip_fake?(row[column], anonymized)

        attrs[column] = @identity.person_name(table, row["id"], column, locale)
      end

      home_place = nil
      billing_place = nil
      rules.each do |column, rule|
        next if rule == "person_name" || partial.include?(column)
        next if skip_fake?(row[column], anonymized)

        attrs[column] = fake_value(
          table, row, column, rule, attrs, locale, country,
          home_place: -> { home_place ||= place_for(table, row, "home", locale, country) },
          billing_place: -> { billing_place ||= place_for(table, row, "billing", locale, country) })
      end
      attrs
    end

    def fake_value(table, row, column, rule, attrs, locale, country, home_place:, billing_place:)
      id = row["id"]
      case rule
      when "emails"
        @identity.emails(name_base(table, id, column, attrs, locale), id, list_size(row[column]))
      when "email"
        base_column = (column == "billing_email") ? "billing_name" : "name"
        base = attrs[base_column] || @identity.person_name(table, id, base_column, locale)
        @identity.email_address(base, id)
      when "phone"
        list_size(row[column]).times.map { |index|
          @identity.phone(country: country, seed: @identity.seed_for(table, id, column, index))
        }.join(", ")
      when "street"
        @identity.street(table, id, column, locale)
      when "zip", "city"
        place = column.start_with?("billing_") ? billing_place.call : home_place.call
        (rule == "zip") ? place.zip : place.city
      when "iban"
        IBAN.generate(country: country, seed: @identity.seed_for(table, id, column))
      when "token"
        @identity.token(table, id, column)
      when "card_number"
        @identity.card_number(table, id, column)
      else
        raise Error, "unexpected fake rule #{rule}"
      end
    end

    def name_base(table, id, column, attrs, locale)
      attrs["name"] || attrs["contact_name"] || @identity.person_name(table, id, column, locale)
    end

    def place_for(table, row, scope, locale, country)
      @identity.place(table, row["id"], scope, locale, country)
    end

    def partial_billing_columns(table, row)
      return [] unless table == "members"

      present = BILLING_COLUMNS.select { |column| row[column].present? }
      return [] if present.empty? || present.size == BILLING_COLUMNS.size

      present
    end

    def skip_fake?(value, anonymized)
      value.blank? || (anonymized && value.to_s == "DELETED")
    end

    def list_size(value)
      count = value.to_s.split(",").count { |part| part.strip.present? }
      count.positive? ? count : 1
    end

    def scrub_text!
      replacement = organization_iban.presence || "[iban]"
      @schema.tables.each do |table|
        next if @classification.drop_tables.include?(table.name)
        next unless table.columns.any? { |column| column.name == "id" }

        table.columns.each do |column|
          next if column.virtual
          next unless Classification::TEXT_TYPES.include?(column.type)
          next if @classification.rule(table.name, column.name) == "iban"

          scrub_column(table.name, column, replacement)
        end
      end
    end

    def scrub_column(table, column, replacement)
      rows = connection.select_all(<<~SQL.squish)
        SELECT #{qcol("id")} AS id, #{qcol(column.name)} AS value
        FROM #{qtable(table)}
        WHERE #{qcol(column.name)} IS NOT NULL
      SQL
      rows.each do |row|
        next unless Scrub.candidate?(row["value"])

        updated = if column.type == "json"
          Scrub.json_value(row["value"], iban: replacement)
        else
          Scrub.text(row["value"], iban: replacement)
        end
        next if updated == row["value"].to_s

        update_row(table, row["id"], { column.name => updated })
      end
    end

    def encrypt!
      token = Organization.type_for_attribute(:api_token).serialize(@classification.placeholder_api_token)
      execute("UPDATE #{qtable("organizations")} SET #{qcol("api_token")} = #{connection.quote(token)}")

      empty = BankConnection.type_for_attribute(:credentials).serialize({})
      execute("UPDATE #{qtable("bank_connections")} SET #{qcol("credentials")} = #{connection.quote(empty)}")
    end

    def select_rows(table, rule_columns)
      selected = [ "id", *rule_columns ]
      selected << "language" if column?(table, "language")
      selected << "country_code" if column?(table, "country_code")
      selected << "member_id" if table != "members" && column?(table, "member_id")
      selected << "anonymized_at" if table == "members"
      connection.select_all(<<~SQL.squish)
        SELECT #{selected.uniq.map { |column| qcol(column) }.join(", ")}
        FROM #{qtable(table)}
      SQL
    end

    def update_row(table, id, attrs)
      return if attrs.empty?

      sets = attrs.map { |column, value| "#{qcol(column)} = #{connection.quote(value)}" }
      execute(<<~SQL.squish)
        UPDATE #{qtable(table)} SET #{sets.join(", ")}
        WHERE #{qcol("id")} = #{connection.quote(id)}
      SQL
    end

    def anonymized_row?(table, row)
      return row["anonymized_at"].present? if table == "members"

      member_context(row["member_id"])&.dig(:anonymized) || false
    end

    def locale_for(row)
      return row["language"] if row["language"].present?

      member_context(row["member_id"])&.dig(:locale) || org_locale
    end

    def country_for(row)
      return row["country_code"].to_s.upcase if row["country_code"].present?

      iban = row["iban"].to_s
      return iban[0, 2].upcase if iban.match?(/\A[A-Za-z]{2}/)

      member_context(row["member_id"])&.dig(:country) || org_country
    end

    def member_context(id)
      return if id.blank?

      @members ||= connection.select_all(
        "SELECT id, language, country_code, anonymized_at FROM members"
      ).each_with_object({}) { |member, map|
        map[member["id"].to_i] = {
          locale: member["language"].presence || org_locale,
          country: member["country_code"].presence || org_country,
          anonymized: member["anonymized_at"].present?
        }
      }
      @members[id.to_i]
    end

    def org_locale
      @org_locale ||= begin
        raw = connection.select_value("SELECT languages FROM organizations ORDER BY id LIMIT 1")
        languages = JSON.parse(raw.presence || "[]")
        languages.first.presence || "fr"
      rescue JSON::ParserError
        "fr"
      end
    end

    def org_country
      @org_country ||= connection.select_value(
        "SELECT country_code FROM organizations ORDER BY id LIMIT 1"
      ).presence || "CH"
    end

    def organization_iban
      connection.select_value("SELECT iban FROM organizations ORDER BY id LIMIT 1")
    end

    def column?(table, name)
      @schema[table]&.columns&.any? { |column| column.name == name }
    end

    def execute(sql)
      connection.execute(sql)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def qtable(name)
      ident!(name)
      connection.quote_table_name(name)
    end

    def qcol(name)
      ident!(name)
      connection.quote_column_name(name)
    end

    def ident!(name)
      return if name.match?(/\A[a-z_][a-z0-9_]*\z/)

      raise Error, "unsafe identifier #{name}"
    end
  end
end

# frozen_string_literal: true

module AnonymizedDump
  # Fail closed on the database that was just anonymized. Upload stays blocked
  # when any check here fails.
  class Verifier
    EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i

    def self.call!(classification = Classification.load)
      violations = new(classification).violations
      return if violations.empty?

      raise Error, violations.join("\n")
    end

    def initialize(classification)
      @classification = classification
      @schema = SchemaColumns.parse
      @violations = []
    end

    def violations
      check_dropped_tables
      check_rich_text
      check_emails
      check_ibans
      check_storage_leftovers
      check_encryption
      @violations
    end

    private

    def check_dropped_tables
      @classification.drop_order.each do |table|
        count = connection.select_value("SELECT COUNT(*) FROM #{qtable(table)}").to_i
        add("#{table} still has #{count} rows") if count.positive?
      end
    end

    def check_rich_text
      types = @classification.purge_rich_text_record_types
      return if types.empty?

      quoted = types.map { |type| connection.quote(type) }.join(", ")
      count = connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{qtable("action_text_rich_texts")}
        WHERE #{qcol("record_type")} IN (#{quoted})
      SQL
      add("support Action Text rows still present (#{count})") if count.positive?
    end

    def check_emails
      each_text_value do |table, column, value|
        policy = @classification.email_policy(table, column)
        next if policy.nil? || policy == "allow"

        value.to_s.scan(EMAIL).each do |email|
          allowed = email.downcase.end_with?("@#{@classification.allowed_email_domain}")
          next if policy == "disposable" && allowed

          add("#{table}.#{column} has #{email}")
        end
      end
    end

    def check_ibans
      org_iban = organization_iban.to_s.delete(" ")
      @classification.each_rule do |table, column, rule|
        next unless rule == "iban"

        each_value(table, column) do |value|
          compact = value.to_s.delete(" ")
          add("#{table}.#{column} has invalid IBAN #{compact}") unless IBAN.valid?(compact)
        end
      end

      each_text_value do |table, column, value|
        next if @classification.rule(table, column) == "iban"

        IBAN.each_valid(value).each do |_token, compact|
          next if org_iban.present? && compact == org_iban

          add("#{table}.#{column} still has IBAN #{compact}")
        end
      end
    end

    def check_storage_leftovers
      each_text_value do |table, column, value|
        text = value.to_s
        add("#{table}.#{column} still points at Active Storage") if text.include?("/rails/active_storage/")
        add("#{table}.#{column} still has a signed_id") if text.include?('"signed_id"')
      end
    end

    def check_encryption
      Organization.find_each do |org|
        unless org.api_token == @classification.placeholder_api_token
          add("organizations.api_token did not decrypt to the dev placeholder")
        end
        %w[postmark_server_token cap_secret_key icalendar_auth_token local_currency_secret].each do |attribute|
          add("organizations.#{attribute} is still set") if org.public_send(attribute).present?
        end
      end

      BankConnection.find_each do |bank|
        credentials = bank.credentials
        add("bank_connections.credentials still has secrets") unless credentials.blank?
      end
    rescue ActiveRecord::Encryption::Errors::Decryption, ActiveRecord::Encryption::Errors::Configuration
      add("an encrypted column could not be decrypted with the current key")
    end

    def each_text_value
      @schema.tables.each do |table|
        next if @classification.drop_tables.include?(table.name)

        table.columns.each do |column|
          next if column.virtual
          next unless Classification::TEXT_TYPES.include?(column.type)

          each_value(table.name, column.name) { |value| yield table.name, column.name, value }
        end
      end
    end

    def each_value(table, column)
      sql = "SELECT #{qcol(column)} AS value FROM #{qtable(table)} WHERE #{qcol(column)} IS NOT NULL"
      connection.select_all(sql).each do |row|
        yield row["value"] if row["value"].present?
      end
    end

    def organization_iban
      connection.select_value("SELECT iban FROM organizations ORDER BY id LIMIT 1")
    end

    def add(message)
      return if @violations.size >= 30

      @violations << message
    end

    def connection
      ActiveRecord::Base.connection
    end

    def qtable(name)
      raise Error, "unsafe identifier #{name}" unless name.match?(/\A[a-z_][a-z0-9_]*\z/)

      connection.quote_table_name(name)
    end

    def qcol(name)
      raise Error, "unsafe identifier #{name}" unless name.match?(/\A[a-z_][a-z0-9_]*\z/)

      connection.quote_column_name(name)
    end
  end
end

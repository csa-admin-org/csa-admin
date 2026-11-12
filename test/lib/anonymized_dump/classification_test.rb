# frozen_string_literal: true

require "test_helper"

class AnonymizedDumpClassificationTest < ActiveSupport::TestCase
  test "schema columns match the classification file" do
    classification = AnonymizedDump::Classification.load
    schema = AnonymizedDump::SchemaColumns.parse

    assert_empty classification.diff(schema.names).missing
    assert_empty classification.diff(schema.names).extra
    assert_includes schema.names["members"], "billing_email"
    assert_not_includes schema.names["basket_contents_depots"], "id"
    assert_includes schema["mail_deliveries"].columns.select(&:virtual).map(&:name), "mailable_id"
    assert_equal(
      %w[searchable_type searchable_id content_primary content_secondary priority updated_at],
      schema.names["search_entries"])
  end

  test "a column added to the schema is unclassified" do
    classification = AnonymizedDump::Classification.load
    schema = AnonymizedDump::SchemaColumns.parse.names
    schema["members"] += [ "surprise_column" ]

    diff = classification.diff(schema)

    assert_includes diff.missing, "members.surprise_column"
    assert_empty diff.extra
  end

  test "a column removed from the schema is an extra classification" do
    classification = AnonymizedDump::Classification.load
    schema = AnonymizedDump::SchemaColumns.parse.names
    schema["members"] -= [ "name" ]

    diff = classification.diff(schema)

    assert_includes diff.extra, "members.name"
  end

  test "encrypted attributes use an encrypt rule" do
    Rails.application.eager_load!
    classification = AnonymizedDump::Classification.load
    missing = []

    ApplicationRecord.descendants.each do |model|
      next if model.abstract_class? || model.encrypted_attributes.blank?

      model.encrypted_attributes.each do |attribute|
        rule = classification.rule(model.table_name, attribute.to_s)
        missing << "#{model.table_name}.#{attribute}" unless rule&.start_with?("encrypt_")
      end
    end

    assert_empty missing
  end
end

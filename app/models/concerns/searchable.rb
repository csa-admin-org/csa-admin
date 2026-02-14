# frozen_string_literal: true

# Makes a model searchable via the FTS5-backed SearchEntry index.
#
# Usage:
#   class Member < ApplicationRecord
#     include Searchable
#     searchable :name, :emails, :phones, :city, :id, priority: 1
#   end
#
# The first attribute is the **primary** field (higher relevance in ranking),
# the rest are **secondary**. Attributes can be columns, Hash/JSON translated
# columns (all locale values joined), or any method the model responds to.
#
# Date-based filtering:
#   Pass `date:` to limit indexing to the current + previous fiscal year.
#   When `date:` names a real DB column, `search_reindex_scope` generates a
#   SQL WHERE clause. For association-based dates, override `search_reindex_scope`.
#
#   searchable :id, :amount, :date, priority: 3, date: :date
#
# Automatic behaviors:
# - Hooks into Discard lifecycle (after_discard/after_undiscard)
# - Appends member.name to secondary text for belongs_to :member
# - Excludes anonymized records from the index
module Searchable
  extend ActiveSupport::Concern

  included do
    class_attribute :_search_primary_attribute, default: nil
    class_attribute :_search_secondary_attributes, default: []
    class_attribute :_search_priority, default: 0
    class_attribute :_search_date_attribute, default: nil

    has_one :search_entry, as: :searchable, dependent: :delete

    after_save :update_search_entry_if_needed
    after_destroy :remove_search_entry

    SearchEntry.register_searchable_model(self)
  end

  class_methods do
    def searchable(*attributes, priority: 0, date: nil)
      attrs = attributes.map(&:to_sym)
      self._search_primary_attribute = attrs.first
      self._search_secondary_attributes = attrs.drop(1)
      self._search_priority = priority
      self._search_date_attribute = date&.to_sym

      # Must check here rather than in `included` because Discard::Model
      # may be included after Searchable in the class body.
      _setup_discard_hooks if _discard_model?
    end

    # Start of the previous fiscal year — records before this are excluded.
    def search_min_date
      Current.org.last_fiscal_year.beginning_of_year
    end

    # Override in models with association-based dates to use joins instead.
    def search_reindex_scope
      scope = respond_to?(:kept) ? kept : all

      if _search_date_attribute && column_names.include?(_search_date_attribute.to_s)
        scope.where(_search_date_attribute => search_min_date..)
      else
        scope
      end
    end

    private

    def _discard_model?
      method_defined?(:discard) || private_method_defined?(:discard)
    end

    def _setup_discard_hooks
      after_discard :remove_search_entry
      after_undiscard :update_search_entry!
    end
  end

  def searchable_primary_text
    return "" unless _search_primary_attribute

    parts = resolve_searchable_value(_search_primary_attribute)

    # When primary attribute is :id, prepend translated model names so users
    # can search "Invoice 42" or "Facture 42" to find specific record types.
    if _search_primary_attribute == :id
      model_names = Current.org.languages.map { |lang|
        I18n.with_locale(lang) { self.class.model_name.human }
      }
      parts = model_names + parts
    end

    normalize_parts(parts)
  end

  def searchable_secondary_text
    parts = _search_secondary_attributes.flat_map { |attr| resolve_searchable_value(attr) }

    # Auto-append member name for belongs_to :member associations
    if self.class.reflect_on_association(:member)
      parts << member&.name
    end

    normalize_parts(parts)
  end

  def search_indexable?
    return true unless _search_date_attribute

    date_value = send(_search_date_attribute)
    return true if date_value.nil?

    date_value >= self.class.search_min_date
  end

  def update_search_entry!
    return if skip_search_indexing?

    SearchEntry.reindex_record(
      self,
      primary_text: searchable_primary_text,
      secondary_text: searchable_secondary_text,
      priority: _search_priority)
  end

  def remove_search_entry
    SearchEntry.remove_record(self)
  end

  private

  def resolve_searchable_value(attr)
    value = respond_to?(attr) ? send(attr) : self[attr]

    case value
    when Hash
      value.values.compact
    when BigDecimal
      [ format("%.2f", value) ]
    when Date
      [ I18n.l(value, format: :number) ]
    else
      Array(value)
    end
  end

  def normalize_parts(parts)
    parts
      .map { |v| v.to_s.squish.presence }
      .compact
      .uniq
      .join(" ")
  end

  def skip_search_indexing?
    (respond_to?(:anonymized?) && anonymized?)
      || (respond_to?(:discarded?) && discarded?)
      || !search_indexable?
  end

  def update_search_entry_if_needed
    if skip_search_indexing?
      remove_search_entry
      return
    end

    if previously_new_record? || search_relevant_changes?
      update_search_entry!
    end
  end

  def search_relevant_changes?
    tracked = [ _search_primary_attribute, *_search_secondary_attributes ].compact.map(&:to_s)

    # Include pluralized JSON columns for translated attributes (e.g. :name → :names)
    tracked_columns = tracked.flat_map { |attr|
      col = attr.pluralize
      self.class.column_names.include?(col) ? [ attr, col ] : [ attr ]
    }

    tracked_columns << "member_id" if self.class.reflect_on_association(:member)

    if _search_date_attribute
      date_col = _search_date_attribute.to_s
      tracked_columns << date_col unless tracked_columns.include?(date_col)
    end

    tracked_columns.any? { |col| saved_change_to_attribute?(col) }
  end
end

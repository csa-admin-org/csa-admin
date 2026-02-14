# frozen_string_literal: true

# Full-text search index backed by SQLite FTS5 with trigram tokenizer.
#
# Each tenant DB has a `search_entries` FTS5 virtual table with two indexed
# columns — `content_primary` and `content_secondary` — so that matches in
# the primary field (name, number) rank higher than secondary (city, email).
# UNINDEXED columns hold metadata for sorting and polymorphic lookup.
#
# Search supports multi-word queries with AND semantics. Terms with 3+ chars
# use FTS5 trigram MATCH; shorter terms are filtered in Ruby.
#
# Usage:
#   SearchEntry.search("dupont laus", limit: 10)
#   SearchEntry.reindex_record(member, primary_text: "...", secondary_text: "...", priority: 10)
#   SearchEntry.remove_record(member)
#   SearchEntry.rebuild!
class SearchEntry < ApplicationRecord
  self.table_name = "search_entries"
  self.primary_key = "rowid"

  # FTS5 creates phantom columns named after the table and `rank`;
  # AR must ignore them to avoid schema introspection errors.
  self.ignored_columns += %w[search_entries rank]

  attribute :rowid, :integer
  attribute :updated_at, :datetime

  belongs_to :searchable, polymorphic: true

  # Scoring is done in Ruby (bm25 is too noisy with trigram tokenizer).
  # Results are ordered by:
  #   1. Primary hits — how many query terms matched in content_primary
  #   2. Priority — lower number = higher importance
  #   3. Recency — most recently updated first
  def self.search(query, limit: 25)
    query = query.to_s.strip
    return [] if query.length < 2

    normalized = normalize_text(query)
    return [] if normalized.blank?

    all_terms = normalized.split(/\s+/).reject(&:blank?)
    return [] if all_terms.empty?

    long_terms = all_terms.select { |t| t.length >= 3 }
    # Only keep short terms when numeric (e.g. "42" for IDs) —
    # alphabetic short terms like "ab" are too vague to be useful.
    short_terms = all_terms.select { |t| t.length < 3 && t.match?(/\A\d+\z/) }

    terms = long_terms + short_terms
    return [] if terms.empty?

    # When only short terms are present (e.g. "42"), we load all entries and
    # filter in Ruby because FTS5 trigram indexes require 3+ char tokens.
    # Acceptable because the index is pruned per-tenant and fiscal year.
    if long_terms.any?
      match_expr = long_terms
        .map { |t| "\"#{t.gsub('"', '""')}\"" }
        .join(" AND ")
      candidates = where("search_entries MATCH ?", match_expr).to_a
    else
      candidates = all.to_a
    end

    if short_terms.any?
      candidates.select! { |entry|
        short_terms.all? { |term|
          entry.content_primary.to_s.include?(term) ||
            entry.content_secondary.to_s.include?(term)
        }
      }
    end

    candidates.sort_by! { |entry|
      primary = entry.content_primary.to_s
      primary_hits = terms.count { |t| primary.include?(t) }
      [ -primary_hits, entry.priority.to_i, -(entry.updated_at&.to_i || 0) ]
    }

    candidates.first(limit)
  end

  # Search the index and return the actual AR records, eager-loaded and ranked.
  def self.lookup(query, limit: 25)
    entries = search(query, limit: limit)
    return [] if entries.empty?

    load_records(entries)
  end

  # FTS5 doesn't support UPDATE or UPSERT, so we delete + insert in a transaction.
  def self.reindex_record(record, primary_text:, secondary_text: "", priority: 0)
    normalized_primary = normalize_text(primary_text)
    normalized_secondary = normalize_text(secondary_text)

    transaction do
      remove_record(record)
      return if normalized_primary.blank? && normalized_secondary.blank?

      connection.execute(sanitize_sql([
        "INSERT INTO search_entries(searchable_type, searchable_id, content_primary, content_secondary, priority, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
        record.class.polymorphic_name,
        record.id,
        normalized_primary,
        normalized_secondary,
        priority,
        record.try(:updated_at) || Time.current
      ]))
    end
  end

  def self.remove_record(record)
    where(
      searchable_type: record.class.polymorphic_name,
      searchable_id: record.id
    ).delete_all
  end

  def self.normalize_text(text)
    return "" if text.blank?

    ActiveSupport::Inflector.transliterate(text.to_s)
      .downcase
      .gsub(/[^a-z0-9 .@,_'-]/, " ")
      .squish
  end

  def self.search_terms(query)
    normalized = normalize_text(query)
    return [] if normalized.blank?

    normalized.split(/\s+/).reject(&:blank?).select { |t|
      t.length >= 3 || (t.length >= 2 && t.match?(/\A\d+\z/))
    }
  end

  # Full reindex of the current tenant. Use the `search:reindex` rake task
  # to run this manually; the nightly job uses `prune_stale_entries!` instead.
  def self.rebuild!
    count = 0

    # Required in development where models are autoloaded lazily —
    # without this, searchable_models would be incomplete.
    Rails.application.eager_load! unless Rails.application.config.eager_load

    searchable_models.each do |model|
      where(searchable_type: model.polymorphic_name).delete_all

      model.search_reindex_scope.find_each do |record|
        next if record.respond_to?(:anonymized?) && record.anonymized?

        record.update_search_entry!
        count += 1
      end
    end

    count
  end

  # Remove entries for records that aged out of the indexable time window.
  # Only affects dated models — dateless ones (Member, Depot, Product) are
  # kept current by save/destroy callbacks.
  def self.prune_stale_entries!
    searchable_models.each do |model|
      next unless model._search_date_attribute

      indexed_ids = where(searchable_type: model.polymorphic_name)
        .pluck(:searchable_id)
        .map(&:to_i)
      next if indexed_ids.empty?

      valid_ids = model.search_reindex_scope
        .where(id: indexed_ids)
        .pluck(:id)

      stale_ids = indexed_ids - valid_ids
      next if stale_ids.empty?

      where(searchable_type: model.polymorphic_name, searchable_id: stale_ids)
        .delete_all
    end
  end

  # Reindex search entries for records that depend on a parent record's
  # searchable text (e.g. member name appears in invoice secondary text).
  # Called from SearchReindexDependentsJob to avoid blocking HTTP responses.
  def self.reindex_dependents!(record)
    case record
    when Member
      %i[memberships invoices payments shop_orders activity_participations].each do |relation|
        record.public_send(relation).includes(:member).find_each(&:update_search_entry!)
      end
    when Activity
      record.participations.includes(:member, :activity).find_each(&:update_search_entry!)
    when Shop::Producer
      record.products.kept.includes(:producer).find_each(&:update_search_entry!)
    end
  end

  def self.load_records(entries)
    grouped = entries.group_by(&:searchable_type)
    records_by_key = {}

    grouped.each do |type, type_entries|
      klass = type.safe_constantize
      next unless klass

      ids = type_entries.map(&:searchable_id)
      records = klass.where(id: ids)

      includes = search_includes_for(klass)
      records = records.includes(*includes) if includes.any?

      records.index_by(&:id).each do |id, record|
        records_by_key[[ type, id ]] = record
      end
    end

    entries.filter_map { |e| records_by_key[[ e.searchable_type, e.searchable_id ]] }
  end

  def self.search_includes_for(klass)
    %i[member activity delivery producer].select { |assoc| klass.reflect_on_association(assoc) }
  end
  private_class_method :search_includes_for

  def self.searchable_models
    @searchable_models ||= []
  end

  def self.register_searchable_model(model)
    searchable_models << model unless searchable_models.include?(model)
  end
end

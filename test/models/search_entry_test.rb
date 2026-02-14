# frozen_string_literal: true

require "test_helper"

class SearchEntryTest < ActiveSupport::TestCase
  setup do
    SearchEntry.delete_all
  end

  test "normalize_text lowercases and removes accents" do
    assert_equal "rene muller", SearchEntry.normalize_text("René Müller")
    assert_equal "cafe", SearchEntry.normalize_text("Café")
    assert_equal "hello world", SearchEntry.normalize_text("HELLO WORLD")
    assert_equal "", SearchEntry.normalize_text(nil)
    assert_equal "", SearchEntry.normalize_text("")
  end

  test "search_terms splits and normalizes query into terms with 2+ chars" do
    assert_equal %w[dupont], SearchEntry.search_terms("Dupont")
    assert_equal %w[foo bar], SearchEntry.search_terms("Foo Bar")
    assert_equal %w[42], SearchEntry.search_terms("42")
    assert_equal %w[rene], SearchEntry.search_terms("René")
    assert_equal %w[foo bar], SearchEntry.search_terms("  Foo   Bar  ")
    assert_empty SearchEntry.search_terms("A")
    assert_empty SearchEntry.search_terms("")
    assert_empty SearchEntry.search_terms(nil)
    assert_equal %w[foo], SearchEntry.search_terms("Foo B")
  end

  test "reindex_record inserts a new entry with primary and secondary" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "John Doe", secondary_text: "john@example.com Zurich", priority: 10)

    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert entry
    assert_equal "john doe", entry.content_primary
    assert_equal "john@example.com zurich", entry.content_secondary
    assert_equal 10, entry.priority.to_i
  end

  test "reindex_record replaces existing entry" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "John Doe", priority: 10)
    SearchEntry.reindex_record(member, primary_text: "John Updated", priority: 5)

    entries = SearchEntry.where(searchable_type: "Member", searchable_id: member.id)
    assert_equal 1, entries.count
    assert_equal "john updated", entries.first.content_primary
  end

  test "reindex_record skips when both texts are blank" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "", secondary_text: "", priority: 10)

    entries = SearchEntry.where(searchable_type: "Member", searchable_id: member.id)
    assert_equal 0, entries.count
  end

  test "reindex_record indexes with only primary text" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "John Doe", priority: 10)

    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert entry
    assert_equal "john doe", entry.content_primary
    assert_equal "", entry.content_secondary
  end

  test "reindex_record indexes with only secondary text" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "", secondary_text: "zurich", priority: 10)

    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert entry
  end

  test "remove_record deletes the entry" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "John Doe", priority: 10)
    assert_equal 1, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count

    SearchEntry.remove_record(member)
    assert_equal 0, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count
  end

  # --- Search: basic matching ---

  test "search returns matching entries" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean-Pierre Dupont", priority: 10)

    results = SearchEntry.search("dupont")
    assert_equal 1, results.count
    assert_equal member.id, results.first.searchable_id
  end

  test "search is accent-insensitive" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "René Müller", secondary_text: "Zürich", priority: 10)

    assert_equal 1, SearchEntry.search("rene").count
    assert_equal 1, SearchEntry.search("muller").count
    assert_equal 1, SearchEntry.search("zurich").count
  end

  test "search is case-insensitive" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", priority: 10)

    assert_equal 1, SearchEntry.search("DUPONT").count
    assert_equal 1, SearchEntry.search("jean").count
  end

  test "search supports substring matching via trigram" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean-Pierre Dupont", priority: 10)

    results = SearchEntry.search("upon")
    assert_equal 1, results.count
  end

  test "search matches in secondary text" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 10)

    results = SearchEntry.search("lausanne")
    assert_equal 1, results.count
  end

  test "search returns empty for short queries" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", priority: 10)

    assert_empty SearchEntry.search("J")
    assert_empty SearchEntry.search("")
  end

  # --- Search: multi-word AND ---

  test "search with multiple words matches all terms (AND semantics)" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 10)

    results = SearchEntry.search("dupont lausanne")
    assert_equal 1, results.count

    results = SearchEntry.search("dupont paris")
    assert_equal 0, results.count
  end

  test "search with multiple words matches across primary and secondary" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 10)

    results = SearchEntry.search("jean laus")
    assert_equal 1, results.count
  end

  test "search with multiple words order does not matter" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 10)

    assert_equal 1, SearchEntry.search("lausanne dupont").count
    assert_equal 1, SearchEntry.search("dupont lausanne").count
  end

  test "search with partial words matches substrings" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "foobar 12345", priority: 10)

    results = SearchEntry.search("foo 123")
    assert_equal 1, results.count
  end

  # --- Search: short numeric terms ---

  test "search with 2-char numeric term matches" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Invoice 42", priority: 5)

    results = SearchEntry.search("42")
    assert_equal 1, results.count
  end

  test "search with mixed long and short numeric terms" do
    john = members(:john)
    mary = members(:mary)
    SearchEntry.reindex_record(john, primary_text: "Invoice 42", secondary_text: "jean dupont", priority: 5)
    SearchEntry.reindex_record(mary, primary_text: "Invoice 99", secondary_text: "mary smith", priority: 5)

    results = SearchEntry.search("dupont 42")
    assert_equal 1, results.count
    assert_equal john.id, results.first.searchable_id
  end

  test "search ignores non-numeric short terms" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", priority: 10)

    assert_empty SearchEntry.search("zz")
    assert_empty SearchEntry.search("ab")
    assert_equal 1, SearchEntry.search("dupont").count
  end

  test "search drops alphabetic short terms in multi-word queries" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 10)

    # "de" is dropped (non-numeric short term), only "dupont" is matched
    results = SearchEntry.search("dupont de")
    assert_equal 1, results.count
  end

  # --- Search: ranking ---

  test "search ranks primary matches above secondary matches" do
    john = members(:john)
    mary = members(:mary)
    # "dupont" is in primary for john, secondary for mary
    SearchEntry.reindex_record(john, primary_text: "Jean Dupont", secondary_text: "lausanne", priority: 5)
    SearchEntry.reindex_record(mary, primary_text: "Mary Smith", secondary_text: "rue dupont", priority: 5)

    results = SearchEntry.search("dupont")
    assert_equal 2, results.count
    assert_equal john.id, results.first.searchable_id, "Primary match should rank first"
  end

  test "search orders by priority when relevance is similar" do
    john = members(:john)
    mary = members(:mary)
    SearchEntry.reindex_record(john, primary_text: "test farmer john", priority: 1)
    SearchEntry.reindex_record(mary, primary_text: "test farmer mary", priority: 5)

    results = SearchEntry.search("farmer")
    assert_equal john.id, results.first.searchable_id
  end

  test "search with short terms boosts primary matches" do
    john = members(:john)
    mary = members(:mary)
    SearchEntry.reindex_record(john, primary_text: "Item 42", secondary_text: "other", priority: 5)
    SearchEntry.reindex_record(mary, primary_text: "Item XX", secondary_text: "ref 42", priority: 5)

    results = SearchEntry.search("42")
    assert_equal 2, results.count
    assert_equal john.id, results.first.searchable_id, "Primary match should rank first for short terms"
  end

  test "search respects limit" do
    5.times do |i|
      member = create_member(name: "Searchtest Member#{i}")
      SearchEntry.reindex_record(member, primary_text: "searchtest member#{i}", priority: 1)
    end

    results = SearchEntry.search("searchtest", limit: 3)
    assert_equal 3, results.count
  end

  test "search handles special FTS5 characters safely" do
    member = members(:john)
    SearchEntry.reindex_record(member, primary_text: "John Doe test", priority: 10)

    # Should not raise even with FTS5 operators in query
    assert_nothing_raised { SearchEntry.search("test AND something") }
    assert_nothing_raised { SearchEntry.search("test OR something") }
    assert_nothing_raised { SearchEntry.search('test "quoted"') }
    assert_nothing_raised { SearchEntry.search("test*") }
  end

  # --- Rebuild ---

  test "rebuild! indexes all searchable models" do
    SearchEntry.delete_all

    count = SearchEntry.rebuild!
    assert count > 0

    # Members should be indexed
    member_entries = SearchEntry.where(searchable_type: "Member")
    assert member_entries.count > 0
  end

  test "rebuild! excludes discarded members" do
    member = discardable_member
    member.discard!
    SearchEntry.delete_all

    SearchEntry.rebuild!

    entries = SearchEntry.where(searchable_type: "Member", searchable_id: member.id)
    assert_equal 0, entries.count
  end

  test "rebuild! excludes anonymized members" do
    member = discardable_member
    member.discard!
    member.anonymize!
    SearchEntry.delete_all

    SearchEntry.rebuild!

    entries = SearchEntry.where(searchable_type: "Member", searchable_id: member.id)
    assert_equal 0, entries.count
  end

  # --- Fiscal year date filtering ---

  test "rebuild! excludes payments older than the past fiscal year" do
    old_payment = create_payment(date: 2.years.ago.to_date)
    recent_payment = create_payment(date: Date.current)
    SearchEntry.delete_all

    SearchEntry.rebuild!

    old_entries = SearchEntry.where(searchable_type: "Payment", searchable_id: old_payment.id)
    recent_entries = SearchEntry.where(searchable_type: "Payment", searchable_id: recent_payment.id)
    assert_equal 0, old_entries.count, "Old payment should not be indexed"
    assert_equal 1, recent_entries.count, "Recent payment should be indexed"
  end

  test "rebuild! includes payments from the past fiscal year" do
    last_fy = Current.org.last_fiscal_year
    payment = create_payment(date: last_fy.beginning_of_year)
    SearchEntry.delete_all

    SearchEntry.rebuild!

    entries = SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id)
    assert_equal 1, entries.count, "Payment from past fiscal year should be indexed"
  end

  test "rebuild! includes old open invoices but excludes old closed ones" do
    old_open_invoice = create_annual_fee_invoice(date: 2.years.ago.to_date)
    old_closed_invoice = create_annual_fee_invoice(date: 2.years.ago.to_date)
    old_closed_invoice.update_column(:state, "closed")
    SearchEntry.delete_all

    SearchEntry.rebuild!

    open_entries = SearchEntry.where(searchable_type: "Invoice", searchable_id: old_open_invoice.id)
    assert_equal 1, open_entries.count, "Old open invoice should be indexed"

    closed_entries = SearchEntry.where(searchable_type: "Invoice", searchable_id: old_closed_invoice.id)
    assert_equal 0, closed_entries.count, "Old closed invoice should not be indexed"
  end

  test "rebuild! excludes memberships that ended before the past fiscal year" do
    SearchEntry.delete_all

    SearchEntry.rebuild!

    membership_entries = SearchEntry.where(searchable_type: "Membership")
    membership_entries.each do |entry|
      membership = Membership.find(entry.searchable_id)
      assert membership.ended_on >= Membership.search_min_date,
        "Membership #{membership.id} (ended_on: #{membership.ended_on}) should not be indexed"
    end
  end

  test "rebuild! always indexes dateless models" do
    SearchEntry.delete_all

    SearchEntry.rebuild!

    assert SearchEntry.where(searchable_type: "Member").count > 0,
      "Members should always be indexed (no date filtering)"
  end

  test "search_min_date returns start of last fiscal year" do
    assert_equal Current.org.last_fiscal_year.beginning_of_year, Payment.search_min_date
  end

  test "search_min_date respects non-January fiscal year start" do
    org(fiscal_year_start_month: 4)

    expected = Current.org.last_fiscal_year.beginning_of_year
    assert_equal 4, expected.month
    assert_equal expected, Payment.search_min_date
  end
end

class SearchableDateFilteringTest < ActiveSupport::TestCase
  setup do
    SearchEntry.delete_all
  end

  test "search_indexable? returns true for dateless models" do
    member = create_member(name: "Always Indexed")
    assert member.search_indexable?
  end

  test "search_indexable? returns true for records within the time window" do
    payment = create_payment(date: Date.current)
    assert payment.search_indexable?
  end

  test "search_indexable? returns false for records before the past fiscal year" do
    payment = create_payment(date: 2.years.ago.to_date)
    assert_not payment.search_indexable?
  end

  test "search_indexable? returns true for records at the exact boundary" do
    payment = create_payment(date: Payment.search_min_date)
    assert payment.search_indexable?
  end

  test "old payment is not indexed on create" do
    payment = create_payment(date: 2.years.ago.to_date)

    entries = SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id)
    assert_equal 0, entries.count, "Old payment should not be indexed on create"
  end

  test "current payment is indexed on create" do
    payment = create_payment(date: Date.current)

    entries = SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id)
    assert_equal 1, entries.count, "Current payment should be indexed on create"
  end

  test "existing entry is removed when record date moves out of window" do
    payment = create_payment(date: Date.current)
    assert_equal 1, SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id).count

    payment.update!(date: 3.years.ago.to_date)
    assert_equal 0, SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id).count,
      "Entry should be removed when date moves out of indexable window"
  end

  test "search_reindex_scope filters by date column for HasFiscalYear models" do
    old_payment = create_payment(date: 2.years.ago.to_date)
    recent_payment = create_payment(date: Date.current)

    scope = Payment.search_reindex_scope
    assert_includes scope, recent_payment
    assert_not_includes scope, old_payment
  end

  test "search_reindex_scope filters by ended_on for Membership" do
    scope = Membership.search_reindex_scope
    scope.each do |membership|
      assert membership.ended_on >= Membership.search_min_date,
        "Membership #{membership.id} should not be in reindex scope"
    end
  end

  test "search_reindex_scope returns all records for dateless models" do
    scope = Member.search_reindex_scope
    assert_equal Member.kept.count, scope.count
  end

  test "activity participation search_reindex_scope uses activity date join" do
    scope = ActivityParticipation.search_reindex_scope
    assert_operator scope.count, :>=, 0, "Scope should be queryable"
    scope.each do |ap|
      assert ap.activity.date >= ActivityParticipation.search_min_date,
        "ActivityParticipation #{ap.id} should not be in reindex scope"
    end
  end
end

class SearchableTest < ActiveSupport::TestCase
  setup do
    SearchEntry.delete_all
  end

  test "member is indexed on create with primary and secondary" do
    member = create_member(name: "Test Searchable", city: "Lausanne")

    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert entry, "Member should be indexed after create"
    assert_includes entry.content_primary, "test searchable"
    assert_includes entry.content_secondary, "lausanne"
  end

  test "member primary text is name, secondary includes city and emails" do
    member = create_member(
      name: "Alice Example",
      emails: "alice@example.com",
      city: "Zürich",
      zip: "8001")

    assert_equal "Alice Example", member.searchable_primary_text

    secondary = member.searchable_secondary_text
    assert_includes secondary, "alice@example.com"
    assert_includes secondary, "Zürich"
    assert_includes secondary, "8001"
    assert_includes secondary, member.id.to_s
  end

  test "member search entry is updated on save" do
    member = create_member(name: "Original Name", city: "Bern")
    member.update!(city: "Genève")

    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert_includes entry.content_secondary, "geneve"
  end

  test "member search entry is removed on discard" do
    member = discardable_member
    member.discard!

    entries = SearchEntry.where(searchable_type: "Member", searchable_id: member.id)
    assert_equal 0, entries.count
  end

  test "member search entry is restored on undiscard" do
    member = create_member
    member.update_columns(state: "inactive")
    member.sessions.create!(
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Agent")
    member.discard!
    SearchEntry.delete_all # ensure clean state after discard callback
    assert_equal 0, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count

    member.undiscard!
    assert_equal 1, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count
  end

  test "member search entry is removed on destroy" do
    member = create_member
    assert_equal 1, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count

    member.destroy!
    assert_equal 0, SearchEntry.where(searchable_type: "Member", searchable_id: member.id).count
  end

  test "member search priority is 1" do
    member = create_member(name: "Priority Test")
    entry = SearchEntry.where(searchable_type: "Member", searchable_id: member.id).first
    assert_equal 1, entry.priority.to_i
  end



  test "payment secondary text includes member name" do
    payment = create_payment

    secondary = payment.searchable_secondary_text
    assert_includes secondary, payment.member.name
  end

  test "invoice is indexed on create" do
    invoice = create_annual_fee_invoice

    entry = SearchEntry.where(searchable_type: "Invoice", searchable_id: invoice.id).first
    assert entry, "Invoice should be indexed after create"
  end

  test "invoice primary text includes translated model names" do
    invoice = create_annual_fee_invoice

    primary = invoice.searchable_primary_text
    Current.org.languages.each do |lang|
      model_name = I18n.with_locale(lang) { Invoice.model_name.human }
      assert_includes primary, model_name, "Primary text should include #{lang} model name"
    end
    assert_includes primary, invoice.id.to_s
  end

  test "member primary text does not include model names" do
    member = create_member(name: "Alice Example")

    assert_equal "Alice Example", member.searchable_primary_text
  end

  test "search 'Inv 42' ranks invoice 42 above other matches" do
    invoice = create_annual_fee_invoice
    member = create_member(name: "Test Member")

    # Ensure both have "42" somewhere so both are candidates
    SearchEntry.reindex_record(member, primary_text: "Test Member", secondary_text: "ref 42", priority: 1)
    SearchEntry.reindex_record(invoice, primary_text: invoice.searchable_primary_text, secondary_text: "42", priority: 3)

    results = SearchEntry.search("Inv #{invoice.id}")
    assert results.any? { |e| e.searchable_type == "Invoice" && e.searchable_id == invoice.id },
      "Invoice should be found when searching with model name prefix"
    assert_equal "Invoice", results.first.searchable_type,
      "Invoice should rank first when searching 'Inv <id>'"
  end

  test "search matches trailing-zero decimals with mixed text and short numeric term" do
    member = create_member(name: "Bau Example")
    invoice = create_annual_fee_invoice(member: member, annual_fee: 347.90)

    results = SearchEntry.search("Bau 90")
    assert results.any? { |entry| entry.searchable_type == "Invoice" && entry.searchable_id == invoice.id }
  end

  test "member name change reindexes dependent entries" do
    member = create_member(name: "Old Name")
    payment = create_payment(member: member, amount: 10, date: Date.current)

    entry = SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id).first
    assert_includes entry.content_secondary, SearchEntry.normalize_text("Old Name")

    perform_enqueued_jobs do
      member.update!(name: "New Name")
    end

    entry = SearchEntry.where(searchable_type: "Payment", searchable_id: payment.id).first
    assert_includes entry.content_secondary, SearchEntry.normalize_text("New Name")
    assert_not_includes entry.content_secondary, SearchEntry.normalize_text("Old Name")
  end

  test "activity title change reindexes participation entries" do
    activity = create_activity(title: "Old Title", date: Date.current)
    participation = ActivityParticipation.create!(member: members(:john), activity: activity)

    entry = SearchEntry.where(searchable_type: "ActivityParticipation", searchable_id: participation.id).first
    assert_includes entry.content_primary, SearchEntry.normalize_text("Old Title")

    perform_enqueued_jobs do
      activity.update!(title: "New Title")
    end

    entry = SearchEntry.where(searchable_type: "ActivityParticipation", searchable_id: participation.id).first
    assert_includes entry.content_primary, SearchEntry.normalize_text("New Title")
    assert_not_includes entry.content_primary, SearchEntry.normalize_text("Old Title")
  end
end

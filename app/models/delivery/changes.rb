# frozen_string_literal: true

class Delivery::Changes
  Change = Data.define(:type, :label, :details)
  LABEL_COLOR = "666666"
  EMPTY_LABEL = /⌀(.+?)⌀/
  ADDRESS_ATTRIBUTES = %w[street zip city].freeze

  Entry = Data.define(:member, :depot_name, :depot_position, :changes) do
    ARROW = " => "
    UNICODE_ARROW = " → "
    DIMMED_HTML = "muted-change is-faint"

    def description
      format_changes("\n") do |c|
        details = c.details&.gsub(EMPTY_LABEL, '\1')&.gsub("\n=>\n", "\n#{UNICODE_ARROW.strip}\n")&.gsub(ARROW, UNICODE_ARROW)
        format_change(c.type, c.label, details)
      end
    end

    def formatted_description
      format_changes("\n") do |c|
        details = c.details&.gsub(EMPTY_LABEL) { "<color rgb='999999'>#{$1}</color>" }
        label = c.label
        case c.type
        when :new
          format_change(c.type, "<b>#{label}</b>", details)
        when :absent
          "<color rgb='#{LABEL_COLOR}'>#{format_change(c.type, label, details)}</color>"
        else
          format_change(c.type, label, details, styled_label: "<color rgb='#{LABEL_COLOR}'>#{label}:</color>")
        end
      end
    end

    def html_description
      format_changes("<br>") do |c|
        details = c.details && c.details
          .gsub("\n=>\n", "\n#{UNICODE_ARROW.strip}\n")
          .gsub(ARROW, UNICODE_ARROW)
          .then { |d| ERB::Util.html_escape(d) }
          .gsub(EMPTY_LABEL) { "<span class=\"missing-data is-inline\">#{$1}</span>" }
          .gsub("\n", "<br>")
        label = ERB::Util.html_escape(c.label)
        case c.type
        when :new
          format_change(c.type, "<strong>#{label}</strong>", details)
        when :absent
          "<span class=\"#{DIMMED_HTML}\">#{format_change(c.type, label, details)}</span>"
        when :address_changed, :home_delivery_address
          format_change(c.type, label, details, styled_label: "<span class=\"#{DIMMED_HTML}\">#{label}:</span><br>")
        else
          format_change(c.type, label, details, styled_label: "<span class=\"#{DIMMED_HTML}\">#{label}:</span>")
        end
      end.html_safe
    end

    def new? = changes.any? { |c| c.type == :new }
    def ended? = changes.any? { |c| c.type == :ended }
    def absent? = changes.any? { |c| c.type == :absent }

    private

    def format_changes(joiner, &block)
      changes.map(&block).join(joiner)
    end

    def format_change(type, label, details, styled_label: nil)
      return label unless details
      type.in?(%i[new ended absent]) ? "#{label} (#{details})" : "#{styled_label || "#{label}:"} #{details}"
    end
  end

  attr_reader :entries

  def initialize(delivery)
    @delivery = delivery
    @entries = compute_entries.freeze
  end

  def any?
    @entries.any?
  end

  def absences_count
    @entries.count(&:absent?)
  end

  def other_changes_count
    @entries.count { |e| !e.absent? }
  end

  def entries_by_depot
    @entries.group_by(&:depot_name)
  end

  private

  MembershipView = Data.define(
    :id,
    :member_id,
    :delivery_cycle_id,
    :ended_on,
    :depot_id,
    :alternate_depot_id,
    :alternate_delivery_cycle_id
  ) do
    def alternate_depot_id? = alternate_depot_id.present?
  end

  MemberAttrs = Data.define(:street, :zip, :city, :delivery_note)
  DepotView = Data.define(:id, :name, :position, :delivery_sheets_mode)
  AuditView = Data.define(:created_at, :changes)
  PendingEntry = Data.define(:member_id, :depot_name, :depot_position, :changes)

  module QuantityLabel
    def quantity_label(name, quantity)
      case quantity
      when 0 then nil
      when 1 then name
      else "#{quantity}x #{name}"
      end
    end
  end

  ComplementView = Data.define(:basket_complement_id, :quantity, :name) do
    include QuantityLabel

    def description = quantity_label(name, quantity)
    def basket_complement = self
  end

  BasketView = Data.define(
    :id,
    :membership_id,
    :member_id,
    :delivery_id,
    :delivery_date,
    :basket_size_id,
    :quantity,
    :state,
    :depot,
    :has_basket_size,
    :basket_size_name,
    :complements,
    :shift_source_dates
  ) do
    include QuantityLabel

    def absent? = state == "absent"
    def depot_id = depot.id
    def baskets_basket_complements = complements

    def basket_description
      return unless has_basket_size

      quantity_label(basket_size_name, quantity)
    end

    def complements_description
      complements.filter_map(&:description).to_sentence.presence
    end

    def description
      [ basket_description, complements_description ].compact.join(" + ").presence || "–"
    end
  end

  def compute_entries
    load_data
    pending = []

    @current_memberships.each do |membership|
      basket = @current_baskets_by_membership_id[membership.id]
      if basket
        pending.concat(entries_for_active_member(membership, basket))
      elsif (entry = entry_for_ended_member(membership))
        pending << entry
      end
    end

    materialize_entries(pending)
  end

  def load_data
    load_memberships
    load_names
    load_baskets
    load_member_attributes
    load_audited_member_changes
    load_cycles
    load_previous_cycle_membership_ids
    load_delivery_complement_ids
    load_home_delivery_overlays
  end

  def load_memberships
    rows = Membership.during_year(@delivery.fy_year).pluck(
      :id,
      :member_id,
      :delivery_cycle_id,
      :ended_on,
      :depot_id,
      :alternate_depot_id,
      :alternate_delivery_cycle_id)
    @current_memberships = rows.map { |row| MembershipView.new(*row) }
    @current_member_ids = @current_memberships.map(&:member_id).uniq
  end

  def load_names
    @depot_views = Depot.pluck(:id, :names, :position, :delivery_sheets_mode).to_h { |id, names, position, mode|
      [ id, DepotView.new(id: id, name: localized_name(names), position: position, delivery_sheets_mode: mode) ]
    }
    @basket_size_names = BasketSize.pluck(:id, :names).to_h { |id, names| [ id, localized_name(names) ] }
    @complement_names = BasketComplement.pluck(:id, :names).to_h { |id, names| [ id, localized_name(names) ] }
  end

  def load_baskets
    current_rows = basket_rows_for_delivery(@delivery.id)
    previous_rows = previous_basket_rows
    complement_ids = (current_rows + previous_rows).map(&:first)
    complements = complements_by_basket_id(complement_ids)
    shifts = shift_dates_by_membership_id(current_rows.map { |row| row[1] })

    @current_baskets_by_membership_id = build_baskets(current_rows, complements, shifts)
      .index_by(&:membership_id)
    @previous_basket_by_member = build_baskets(previous_rows, complements).index_by(&:member_id)
  end

  def basket_rows_for_delivery(delivery_id)
    Basket.unscoped
      .joins(:membership)
      .where(baskets: { delivery_id: delivery_id })
      .pluck(
        "baskets.id",
        "baskets.membership_id",
        "memberships.member_id",
        "baskets.basket_size_id",
        "baskets.quantity",
        "baskets.state",
        "baskets.depot_id",
        "baskets.delivery_id")
  end

  def previous_basket_rows
    member_ids = @current_member_ids
    return [] if member_ids.empty?

    previous_membership_ids = Membership.during_year(@delivery.fy_year - 1)
      .where(member_id: member_ids)
      .pluck(:id)
    membership_ids = @current_memberships.map(&:id) + previous_membership_ids
    return [] if membership_ids.empty?

    cutoff_date = @delivery.date - 6.months
    ranked = Basket.unscoped
      .joins(:delivery, :membership)
      .where(membership_id: membership_ids)
      .where(deliveries: { date: cutoff_date...@delivery.date })
      .select(
        "baskets.id",
        "baskets.membership_id",
        "memberships.member_id",
        "baskets.basket_size_id",
        "baskets.quantity",
        "baskets.state",
        "baskets.depot_id",
        "baskets.delivery_id",
        "deliveries.date AS delivery_date",
        "ROW_NUMBER() OVER (PARTITION BY memberships.member_id ORDER BY deliveries.date DESC, baskets.id DESC) AS rn")

    Basket.unscoped
      .from("(#{ranked.to_sql}) AS ranked")
      .where("ranked.rn = 1")
      .pluck(
        "ranked.id",
        "ranked.membership_id",
        "ranked.member_id",
        "ranked.basket_size_id",
        "ranked.quantity",
        "ranked.state",
        "ranked.depot_id",
        "ranked.delivery_id",
        "ranked.delivery_date")
  end

  def complements_by_basket_id(basket_ids)
    return {} if basket_ids.empty?

    BasketsBasketComplement.ordered
      .where(basket_id: basket_ids)
      .pluck(
        "baskets_basket_complements.basket_id",
        "baskets_basket_complements.basket_complement_id",
        "baskets_basket_complements.quantity")
      .group_by(&:first)
      .transform_values { |rows|
        rows.map { |_basket_id, complement_id, quantity|
          ComplementView.new(
            basket_complement_id: complement_id,
            quantity: quantity,
            name: @complement_names[complement_id])
        }
      }
  end

  def shift_dates_by_membership_id(membership_ids)
    membership_ids = membership_ids.uniq
    return {} if membership_ids.empty?

    BasketShift.where(target_delivery_id: @delivery.id, membership_id: membership_ids)
      .joins(:source_delivery)
      .order(:id)
      .pluck(:membership_id, "deliveries.date")
      .group_by(&:first)
      .transform_values { |rows| rows.map { |_membership_id, date| coerce_date(date) } }
  end

  def build_baskets(rows, complements_by_basket_id, shifts_by_membership_id = {})
    rows.map { |id, membership_id, member_id, basket_size_id, quantity, state, depot_id, delivery_id, delivery_date|
      BasketView.new(
        id: id,
        membership_id: membership_id,
        member_id: member_id,
        delivery_id: delivery_id,
        delivery_date: coerce_date(delivery_date || @delivery.date),
        basket_size_id: basket_size_id,
        quantity: quantity,
        state: state,
        depot: @depot_views.fetch(depot_id),
        has_basket_size: @basket_size_names.key?(basket_size_id),
        basket_size_name: @basket_size_names[basket_size_id],
        complements: complements_by_basket_id[id] || [],
        shift_source_dates: shifts_by_membership_id[membership_id] || [])
    }
  end

  def load_member_attributes
    @members_by_id = {}
    return if @current_member_ids.empty?

    Member.where(id: @current_member_ids).pluck(:id, :street, :zip, :city, :delivery_note).each do |id, street, zip, city, note|
      @members_by_id[id] = MemberAttrs.new(street: street, zip: zip, city: city, delivery_note: note)
    end
  end

  def load_audited_member_changes
    @name_change_details_by_member_id = {}
    @address_change_details_by_member_id = {}
    @delivery_note_change_details_by_member_id = {}
    return if @previous_basket_by_member.empty?

    start_date = @previous_basket_by_member.values.map(&:delivery_date).min
    rows = Audit
      .where(auditable_type: "Member", auditable_id: @previous_basket_by_member.keys)
      .where(created_at: start_date...(@delivery.date + 1.day))
      .order(:created_at, :id)
      .pluck(:auditable_id, :created_at, :audited_changes)

    rows.group_by(&:first).each do |member_id, member_rows|
      audits = member_rows.map { |_member_id, created_at, changes|
        AuditView.new(created_at: coerce_time(created_at), changes: indifferent_changes(changes))
      }
      audits = recent_member_audits(member_id, audits)
      next if audits.empty?

      add_change_detail(@name_change_details_by_member_id, member_id, attribute_change_details(audits, "name"))
      add_change_detail(@address_change_details_by_member_id, member_id, address_change_details(member_id, audits))
      add_change_detail(
        @delivery_note_change_details_by_member_id,
        member_id,
        attribute_change_details(audits, "delivery_note"))
    end
  end

  def load_cycles
    cycle_ids = @current_memberships.flat_map { |membership|
      [ membership.delivery_cycle_id, membership.alternate_delivery_cycle_id ]
    }.compact.uniq
    @cycles_by_id = DeliveryCycle.where(id: cycle_ids).includes(:periods).index_by(&:id)
    @included_cycle_ids = @cycles_by_id.each_with_object(Set.new) { |(id, cycle), set|
      next if cycle.discarded?

      set << id if cycle_delivery_ids(cycle, @delivery.fy_year).include?(@delivery.id)
    }
  end

  def load_previous_cycle_membership_ids
    @previous_cycle_delivery_basket_membership_ids = {}
    delivery_id_by_cycle_id = @included_cycle_ids.filter_map { |cycle_id|
      delivery_id = previous_delivery_id_for(cycle_id)
      [ cycle_id, delivery_id ] if delivery_id
    }.to_h
    return if delivery_id_by_cycle_id.empty?

    membership_ids_by_delivery_id = Hash.new { |hash, key| hash[key] = Set.new }
    Basket.unscoped.where(delivery_id: delivery_id_by_cycle_id.values.uniq)
      .pluck(:delivery_id, :membership_id)
      .each { |delivery_id, membership_id| membership_ids_by_delivery_id[delivery_id] << membership_id }

    delivery_id_by_cycle_id.each do |cycle_id, delivery_id|
      @previous_cycle_delivery_basket_membership_ids[cycle_id] = membership_ids_by_delivery_id[delivery_id]
    end
  end

  def load_delivery_complement_ids
    @current_delivery_complement_ids = @delivery.basket_complement_ids.to_set
    @previous_delivery_complement_ids = {}
    delivery_ids = @previous_basket_by_member.values.map(&:delivery_id).uniq
    return if delivery_ids.empty?

    Delivery.where(id: delivery_ids)
      .joins(:basket_complements)
      .pluck("deliveries.id", "basket_complements_deliveries.basket_complement_id")
      .each do |delivery_id, complement_id|
        (@previous_delivery_complement_ids[delivery_id] ||= Set.new) << complement_id
      end
  end

  def load_home_delivery_overlays
    @overlay_text = {}
    pairs = home_delivery_pairs
    return if pairs.empty?

    rows = HomeDeliveryAddress
      .joins(:home_delivery_address_deliveries)
      .where(member_id: pairs.map(&:first).uniq)
      .where(home_delivery_address_deliveries: { delivery_id: pairs.map(&:last).uniq })
      .pluck(
        "home_delivery_addresses.member_id",
        "home_delivery_address_deliveries.delivery_id",
        "home_delivery_addresses.name",
        "home_delivery_addresses.street",
        "home_delivery_addresses.zip",
        "home_delivery_addresses.city",
        "home_delivery_addresses.note")

    eligible = pairs.to_set
    rows.each do |member_id, delivery_id, name, street, zip, city, note|
      next unless eligible.include?([ member_id, delivery_id ])

      @overlay_text[[ member_id, delivery_id ]] = overlay_text(name, street, zip, city, note, member_id)
    end
  end

  def home_delivery_pairs
    pairs = []
    @current_baskets_by_membership_id.each_value do |basket|
      next unless home_delivery?(basket)

      pairs << [ basket.member_id, basket.delivery_id ]
    end
    @previous_basket_by_member.each do |member_id, basket|
      next unless home_delivery?(basket)

      pairs << [ member_id, basket.delivery_id ]
    end
    pairs.uniq
  end

  def home_delivery?(basket)
    basket.depot.delivery_sheets_mode == "home_delivery"
  end

  def overlay_text(name, street, zip, city, note, member_id)
    address = [ name, street, "#{zip} #{city}" ].compact_blank.join("\n")
    sheet_note = note.presence || @members_by_id[member_id]&.delivery_note
    [ address, sheet_note ].compact_blank.join("\n")
  end

  def materialize_entries(pending)
    return [] if pending.empty?

    members = Member.where(id: pending.map(&:member_id).uniq).index_by(&:id)
    pending.map { |row|
      Entry.new(
        member: members.fetch(row.member_id),
        depot_name: row.depot_name,
        depot_position: row.depot_position,
        changes: row.changes)
    }.sort_by { |entry| [ entry.depot_position, entry.member.name ] }
  end

  def entries_for_active_member(membership, basket)
    prev_basket = @previous_basket_by_member[membership.member_id]

    if prev_basket.nil?
      changes = [ build_change(:new, details: basket.description) ]
      changes.concat(detect_home_delivery_address_change(membership, basket, nil))
      return [ pending_entry(membership.member_id, basket.depot, changes) ]
    end

    changes = []
    changes.concat(detect_audited_member_changes(membership, basket))
    changes.concat(detect_home_delivery_address_change(membership, basket, prev_basket))

    if depot_changed?(membership, basket, prev_basket)
      changes << build_change(:depot_changed, details: "#{prev_basket.depot.name} => #{basket.depot.name}")
    end

    if basket.absent? && !prev_basket.absent?
      changes << build_change(:absent, details: prev_basket.basket_description || empty_label)
    else
      changes.concat(detect_basket_content_changes(basket, prev_basket))
    end

    return [] if changes.empty?

    [ pending_entry(membership.member_id, basket.depot, changes) ]
  end

  def pending_entry(member_id, depot, changes)
    PendingEntry.new(
      member_id: member_id,
      depot_name: depot.name,
      depot_position: depot.position,
      changes: changes)
  end

  def recent_member_audits(member_id, audits)
    prev_basket = @previous_basket_by_member[member_id]
    audits.select { |audit| audit.created_at.to_date > prev_basket.delivery_date }
  end

  def add_change_detail(details_by_member_id, member_id, details)
    details_by_member_id[member_id] = details if details
  end

  def attribute_change_details(audits, attribute)
    changes = audits.filter_map { |audit| audit.changes[attribute] }
    return if changes.empty?

    previous_value = audited_value_description(changes.first.first)
    current_value = audited_value_description(changes.last.last)
    return if previous_value == current_value

    "#{previous_value} => #{current_value}"
  end

  def address_change_details(member_id, audits)
    return unless ADDRESS_ATTRIBUTES.any? { |attribute| audits.any? { |audit| audit.changes[attribute] } }

    previous_values = {}
    current_values = {}
    member = @members_by_id[member_id]

    ADDRESS_ATTRIBUTES.each do |attribute|
      changes = audits.filter_map { |audit| audit.changes[attribute] }
      previous_values[attribute], current_values[attribute] =
        if changes.any?
          [ changes.first.first, changes.last.last ]
        else
          [ member.public_send(attribute), member.public_send(attribute) ]
        end
    end

    previous_address = address_description(previous_values)
    current_address = address_description(current_values)
    return if previous_address == current_address

    "#{previous_address}\n=>\n#{current_address}"
  end

  def address_description(values)
    [
      values["street"],
      [ values["zip"], values["city"] ].compact_blank.join(" ")
    ].compact_blank.join("\n").presence || empty_label
  end

  def audited_value_description(value)
    value.presence || empty_label
  end

  def detect_home_delivery_address_change(membership, basket, prev_basket)
    return [] unless home_delivery?(basket)
    return [] if basket.absent?

    current = @overlay_text[[ membership.member_id, basket.delivery_id ]]
    previous =
      if prev_basket && home_delivery?(prev_basket) && !prev_basket.absent?
        @overlay_text[[ membership.member_id, prev_basket.delivery_id ]]
      end
    return [] if current == previous

    from = previous.presence || empty_label
    to = current.presence || empty_label
    [ build_change(:home_delivery_address, details: "#{from}\n=>\n#{to}") ]
  end

  def detect_audited_member_changes(membership, basket)
    changes = []

    name_change = build_audited_member_change(:name_changed, membership)
    changes << name_change if name_change

    if home_delivery?(basket)
      address_change = build_audited_member_change(:address_changed, membership)
      delivery_note_change = build_audited_member_change(:delivery_note_changed, membership)
      changes << address_change if address_change
      changes << delivery_note_change if delivery_note_change
    end

    changes
  end

  def build_audited_member_change(type, membership)
    details_by_member_id =
      case type
      when :name_changed then @name_change_details_by_member_id
      when :address_changed then @address_change_details_by_member_id
      when :delivery_note_changed then @delivery_note_change_details_by_member_id
      end
    details = details_by_member_id[membership.member_id]
    build_change(type, details: details) if details
  end

  def depot_changed?(membership, basket, prev_basket)
    return false if basket.depot_id == prev_basket.depot_id
    return true unless membership.alternate_depot_id?

    basket.depot_id != expected_depot_id(membership, @delivery.id, @delivery.date) ||
      prev_basket.depot_id != expected_depot_id(membership, prev_basket.delivery_id, prev_basket.delivery_date)
  end

  def expected_depot_id(membership, delivery_id, date)
    if membership.alternate_depot_id? && cycle_includes_delivery?(membership.alternate_delivery_cycle_id, delivery_id, date)
      membership.alternate_depot_id
    else
      membership.depot_id
    end
  end

  def cycle_includes_delivery?(cycle_id, delivery_id, date)
    cycle = @cycles_by_id[cycle_id]
    return false unless cycle

    cycle_delivery_ids(cycle, Current.org.fiscal_year_for(date).year).include?(delivery_id)
  end

  def previous_delivery_id_for(cycle_id)
    cycle = @cycles_by_id[cycle_id]
    return unless cycle

    dates = cycle_deliveries(cycle, @delivery.fy_year)
    dates.reverse_each.find { |delivery| delivery.date < @delivery.date }&.id
  end

  def cycle_delivery_ids(cycle, year)
    cycle_deliveries(cycle, year).map(&:id)
  end

  def cycle_deliveries(cycle, year)
    @cycle_deliveries ||= {}
    year = Current.org.fiscal_year_for(year).year
    @cycle_deliveries[[ cycle.id, year ]] ||= cycle.deliveries(year)
  end

  def detect_basket_content_changes(basket, prev_basket)
    changes = []

    if basket.shift_source_dates.any?
      source_dates = basket.shift_source_dates.map { |date| I18n.l(date, format: :short_no_year) }
      shift_label = BasketShift.model_name.human.downcase
      changes << build_change(:basket_changed,
        details: "#{basket.basket_description || empty_label} (#{shift_label} #{source_dates.join(', ')})")
    elsif basket_changed?(basket, prev_basket)
      changes << build_change(:basket_changed,
        details: "#{prev_basket.basket_description || empty_label} => #{basket.basket_description || empty_label}")
    end

    complement_change = detect_complement_change(basket, prev_basket)
    changes << complement_change if complement_change

    changes
  end

  def basket_changed?(basket, prev_basket)
    basket.basket_size_id != prev_basket.basket_size_id ||
      basket.quantity != prev_basket.quantity
  end

  def detect_complement_change(basket, prev_basket)
    prev_delivery_complements = @previous_delivery_complement_ids[prev_basket.delivery_id] || Set.new
    comparable_ids = @current_delivery_complement_ids & prev_delivery_complements
    return if comparable_ids.empty?

    current_set = complement_quantities(basket, comparable_ids)
    previous_set = complement_quantities(prev_basket, comparable_ids)
    return if current_set == previous_set

    details = complement_diff_text(previous_set, current_set, basket, prev_basket)
    return if details.blank?

    build_change(:complements_changed, details: details)
  end

  def complement_quantities(basket, comparable_ids)
    basket.baskets_basket_complements.each_with_object({}) do |bbc, quantities|
      quantities[bbc.basket_complement_id] = bbc.quantity if comparable_ids.include?(bbc.basket_complement_id)
    end
  end

  def complement_diff_text(previous_set, current_set, current_basket, previous_basket)
    complements_by_id = {}
    current_basket.baskets_basket_complements.each { |bbc| complements_by_id[bbc.basket_complement_id] = bbc.basket_complement }
    previous_basket.baskets_basket_complements.each { |bbc| complements_by_id[bbc.basket_complement_id] = bbc.basket_complement }

    changes = []
    (previous_set.keys | current_set.keys).sort.each do |id|
      complement = complements_by_id[id]
      next unless complement

      prev_qty = previous_set[id]
      curr_qty = current_set[id]

      if prev_qty && !curr_qty
        changes << "– #{complement_desc(complement, prev_qty)}"
      elsif !prev_qty && curr_qty
        changes << "+ #{complement_desc(complement, curr_qty)}"
      elsif prev_qty != curr_qty
        changes << "#{complement_desc(complement, prev_qty)} => #{complement_desc(complement, curr_qty)}"
      end
    end

    changes.join(", ")
  end

  def complement_desc(complement, quantity)
    quantity == 1 ? complement.name : "#{quantity}x #{complement.name}"
  end

  def empty_label
    "⌀#{I18n.t("active_admin.empty").upcase}⌀"
  end

  def entry_for_ended_member(membership)
    return unless @included_cycle_ids.include?(membership.delivery_cycle_id)
    return unless membership.ended_on < @delivery.date

    prev_basket = @previous_basket_by_member[membership.member_id]
    return unless prev_basket

    # Only show as ended if the member had a basket on the previous delivery
    # of their cycle. This avoids showing long-ended members repeatedly.
    prev_cycle_membership_ids = @previous_cycle_delivery_basket_membership_ids[membership.delivery_cycle_id]
    return unless prev_cycle_membership_ids&.include?(membership.id)

    pending_entry(membership.member_id, prev_basket.depot, [ build_change(:ended, details: prev_basket.description) ])
  end

  def build_change(type, details: nil)
    label =
      case type
      when :absent
        Basket.human_attribute_name(:absent).capitalize
      when :name_changed
        Member.human_attribute_name(:name)
      when :address_changed
        Member.human_attribute_name(:address)
      when :delivery_note_changed
        Member.human_attribute_name(:delivery_note)
      else
        I18n.t("delivery.change_types.#{type}")
      end

    Change.new(type: type, label: label, details: details)
  end

  def localized_name(names)
    names = json_hash(names)
    value = names[I18n.locale.to_s].presence || names[Current.org.default_locale.to_s].presence
    value&.html_safe
  end

  def json_hash(value)
    case value
    when Hash then value.stringify_keys
    when String then JSON.parse(value)
    else {}
    end
  end

  def indifferent_changes(changes)
    json_hash(changes).with_indifferent_access
  end

  def coerce_date(value)
    case value
    when Date then value
    when Time, DateTime, ActiveSupport::TimeWithZone then value.to_date
    else Date.parse(value.to_s)
    end
  end

  def coerce_time(value)
    case value
    when Time, DateTime, ActiveSupport::TimeWithZone then value
    else Time.zone.parse(value.to_s)
    end
  end
end

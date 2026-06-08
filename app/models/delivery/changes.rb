# frozen_string_literal: true

class Delivery::Changes
  Change = Data.define(:type, :label, :details)
  LABEL_COLOR = "666666"
  EMPTY_LABEL = /⌀(.+?)⌀/
  ADDRESS_ATTRIBUTES = %w[street zip city].freeze

  Entry = Data.define(:member, :depot_name, :changes) do
    ARROW = " => "
    UNICODE_ARROW = " → "
    DIMMED_HTML = "text-gray-400 dark:text-gray-600"

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
          .gsub(EMPTY_LABEL) { "<span class=\"missing-data inline! w-auto! py-0! px-1!\">#{$1}</span>" }
          .gsub("\n", "<br>")
        label = ERB::Util.html_escape(c.label)
        case c.type
        when :new
          format_change(c.type, "<strong>#{label}</strong>", details)
        when :absent
          "<span class=\"#{DIMMED_HTML}\">#{format_change(c.type, label, details)}</span>"
        when :address_changed
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

  def compute_entries
    load_data
    entries = []

    @current_memberships.each do |membership|
      basket = @current_baskets_by_membership_id[membership.id]

      if basket
        entries.concat(entries_for_active_member(membership, basket))
      else
        entry = entry_for_ended_member(membership)
        entries << entry if entry
      end
    end

    entries.sort_by { |e| [ e.depot_name.to_s, e.member.name ] }
  end

  def load_data
    @current_memberships = Membership
      .during_year(@delivery.fy_year)
      .includes(:member, :delivery_cycle, :alternate_delivery_cycle)
      .to_a

    current_member_ids = @current_memberships.map(&:member_id)
    @current_members_by_id = @current_memberships.map(&:member).index_by(&:id)

    @previous_memberships_by_member = Membership
      .during_year(@delivery.fy_year - 1)
      .where(member_id: current_member_ids)
      .index_by(&:member_id)

    @current_baskets_by_membership_id = @delivery.baskets
      .includes(:basket_size, :depot, shifts_as_target: :source_delivery, baskets_basket_complements: :basket_complement)
      .index_by(&:membership_id)

    @included_cycles = DeliveryCycle.for(@delivery)
    @included_cycle_ids = @included_cycles.map(&:id).to_set

    @current_delivery_complement_ids = @delivery.basket_complement_ids.to_set

    load_previous_baskets
    load_audited_member_changes
    load_previous_delivery_complement_ids
    load_previous_cycle_deliveries
  end

  def load_previous_baskets
    cutoff_date = @delivery.date - 6.months
    all_valid_membership_ids = []
    @membership_to_member = {}

    @current_memberships.each do |m|
      all_valid_membership_ids << m.id
      @membership_to_member[m.id] = m.member_id

      if (prev = @previous_memberships_by_member[m.member_id])
        all_valid_membership_ids << prev.id
        @membership_to_member[prev.id] = prev.member_id
      end
    end

    previous_baskets = Basket
      .where(membership_id: all_valid_membership_ids)
      .joins(:delivery)
      .where(deliveries: { date: cutoff_date...@delivery.date })
      .includes(:basket_size, :depot, :delivery, baskets_basket_complements: :basket_complement)
      .reorder("deliveries.date DESC")
      .to_a

    @previous_basket_by_member = {}
    previous_baskets.each do |basket|
      member_id = @membership_to_member[basket.membership_id]
      next unless member_id
      # Keep only the most recent previous basket per member
      @previous_basket_by_member[member_id] ||= basket
    end
  end

  def load_audited_member_changes
    @name_change_details_by_member_id = {}
    @address_change_details_by_member_id = {}
    @delivery_note_change_details_by_member_id = {}
    member_ids = @previous_basket_by_member.keys
    return if member_ids.empty?

    start_date = @previous_basket_by_member.values.map { |b| b.delivery.date }.min
    audits = Audit
      .where(auditable_type: "Member", auditable_id: member_ids)
      .where(created_at: start_date...(@delivery.date + 1.day))
      .order(:created_at, :id)
      .to_a

    audits.group_by(&:auditable_id).each do |member_id, member_audits|
      member_audits = recent_member_audits(member_id, member_audits)
      next if member_audits.empty?

      add_change_detail(@name_change_details_by_member_id, member_id, attribute_change_details(member_audits, "name"))
      add_change_detail(@address_change_details_by_member_id, member_id, address_change_details(member_id, member_audits))
      add_change_detail(@delivery_note_change_details_by_member_id, member_id, attribute_change_details(member_audits, "delivery_note"))
    end
  end

  def recent_member_audits(member_id, audits)
    prev_basket = @previous_basket_by_member[member_id]
    audits.select { |audit| audit.created_at.to_date > prev_basket.delivery.date }
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
    member = @current_members_by_id[member_id]

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

  def load_previous_cycle_deliveries
    @previous_cycle_delivery_basket_membership_ids = {}

    @included_cycles.each do |cycle|
      cycle_deliveries = cycle.deliveries(@delivery.fy_year).select { |d| d.date < @delivery.date }
      prev_delivery = cycle_deliveries.last
      next unless prev_delivery

      basket_membership_ids = prev_delivery.baskets.pluck(:membership_id).to_set
      @previous_cycle_delivery_basket_membership_ids[cycle.id] = basket_membership_ids
    end
  end

  def load_previous_delivery_complement_ids
    previous_delivery_ids = @previous_basket_by_member.values.map(&:delivery_id).uniq

    @previous_delivery_complement_ids = {}

    if previous_delivery_ids.any?
      Delivery.where(id: previous_delivery_ids)
        .joins(:basket_complements)
        .pluck("deliveries.id", "basket_complements_deliveries.basket_complement_id")
        .each do |delivery_id, complement_id|
          (@previous_delivery_complement_ids[delivery_id] ||= Set.new) << complement_id
        end
    end
  end

  def entries_for_active_member(membership, basket)
    prev_basket = @previous_basket_by_member[membership.member_id]

    if prev_basket.nil?
      return [ build_entry(membership.member, basket.depot.name, [ build_change(:new, details: basket.description) ]) ]
    end

    changes = []

    changes.concat(detect_audited_member_changes(membership, basket))

    if depot_changed?(membership, basket, prev_basket)
      changes << build_change(:depot_changed,
        details: "#{prev_basket.depot.name} => #{basket.depot.name}")
    end

    if basket.absent? && !prev_basket.absent?
      changes << build_change(:absent, details: prev_basket.basket_description || empty_label)
    else
      changes.concat(detect_basket_content_changes(basket, prev_basket))
    end

    return [] if changes.empty?

    [ build_entry(membership.member, basket.depot.name, changes) ]
  end

  def detect_audited_member_changes(membership, basket)
    changes = []

    name_change = build_audited_member_change(:name_changed, membership)
    changes << name_change if name_change

    if basket.depot.delivery_sheets_mode == "home_delivery"
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

    expected_current_depot_id, = membership.send(:depot_for, @delivery)
    expected_previous_depot_id, = membership.send(:depot_for, prev_basket.delivery)

    basket.depot_id != expected_current_depot_id ||
      prev_basket.depot_id != expected_previous_depot_id
  end

  def detect_basket_content_changes(basket, prev_basket)
    changes = []

    if basket.shifts_as_target.any?
      source_dates = basket.shifts_as_target.map { |s|
        I18n.l(s.source_delivery.date, format: :short_no_year)
      }
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
    basket.baskets_basket_complements.each_with_object({}) do |bbc, h|
      h[bbc.basket_complement_id] = bbc.quantity if comparable_ids.include?(bbc.basket_complement_id)
    end
  end

  def complement_diff_text(previous_set, current_set, current_basket, previous_basket)
    complements_by_id = {}
    current_basket.baskets_basket_complements.each { |bbc| complements_by_id[bbc.basket_complement_id] = bbc.basket_complement }
    previous_basket.baskets_basket_complements.each { |bbc| complements_by_id[bbc.basket_complement_id] = bbc.basket_complement }

    changes = []
    all_ids = (previous_set.keys | current_set.keys).sort

    all_ids.each do |id|
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

    build_entry(membership.member, prev_basket.depot.name, [ build_change(:ended, details: prev_basket.description) ])
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

  def build_entry(member, depot_name, changes)
    Entry.new(
      member: member,
      depot_name: depot_name,
      changes: changes)
  end
end

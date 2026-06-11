# frozen_string_literal: true

module ActiveAdmin::MenuBadgeHelper
  def menu_label_with_badge(item, badge_class: "menu-icon-badge")
    label = item.label(self)
    badge = menu_badge_for_item(item, label, badge_class: badge_class)

    badge ? safe_join([ label, badge ]) : label
  end

  def menu_badge(count, label:, key:, badge_class:)
    return unless count.positive?

    content_tag :span,
      count,
      class: [ badge_class, ("menu-badge-wide" if count >= 10) ].compact.join(" "),
      title: label,
      aria: { label: label },
      data: { menu_badge: key }
  end

  def menu_badge_for_item(item, label, badge_class:)
    return if label.to_s.include?("data-menu-badge")

    case item.id.to_s
    when "members"
      count = pending_members_menu_count
      menu_badge(count,
        label: "#{count} #{Member.model_name.human(count: count)} #{t("active_admin.scopes.pending").downcase}",
        key: :members,
        badge_class: badge_class)
    when "navshop", "shop_orders"
      count = pending_shop_orders_menu_count
      menu_badge(count,
        label: "#{count} #{Shop::Order.model_name.human(count: count)} #{t("active_admin.scopes.pending").downcase}",
        key: :shop,
        badge_class: badge_class)
    when "activities_human_name", "activity_participations"
      count = pending_activity_participations_menu_count
      menu_badge(count,
        label: "#{count} #{ActivityParticipation.model_name.human(count: count)} #{t("active_admin.scopes.pending").downcase}",
        key: :activities,
        badge_class: badge_class)
    end
  end

  def pending_members_menu_count
    @pending_members_menu_count ||= Member.pending.count
  end

  def pending_shop_orders_menu_count
    return 0 unless feature?("shop")

    @pending_shop_orders_menu_count ||= Shop::Order.pending.count
  end

  def pending_activity_participations_menu_count
    return 0 unless feature?("activity")

    @pending_activity_participations_menu_count ||= ActivityParticipation.pending.count
  end

  def pending_shop_orders_menu_path_params
    { scope: :pending }.tap do |path_params|
      if delivery_gid = pending_shop_orders_menu_delivery_gid
        path_params[:q] = { _delivery_gid_eq: delivery_gid }
      end
    end
  end

  def pending_shop_orders_menu_delivery_gid
    return @pending_shop_orders_menu_delivery_gid if defined?(@pending_shop_orders_menu_delivery_gid)

    deliveries = Shop::Order.pending
      .select(:delivery_type, :delivery_id)
      .distinct
      .limit(2)
      .filter_map(&:delivery)

    @pending_shop_orders_menu_delivery_gid = deliveries.one? ? deliveries.first.gid : nil
  end

  def pending_members_menu_path
    if pending_members_menu_count.positive?
      members_path(scope: :pending)
    else
      members_path
    end
  end

  def smart_or_pending_shop_orders_path
    if pending_shop_orders_menu_count.positive?
      shop_orders_path(**pending_shop_orders_menu_path_params)
    else
      smart_shop_orders_path
    end
  end

  def current_year_or_pending_activity_participations_path
    if pending_activity_participations_menu_count.positive?
      activity_participations_path(scope: :pending)
    else
      activity_participations_path(q: { during_year: Current.fiscal_year.year })
    end
  end
end

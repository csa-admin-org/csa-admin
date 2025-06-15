# frozen_string_literal: true

module MembershipsHelper
  def basket_description(basket, text_only: false)
    parts = [ basket_size_description(basket, text_only: text_only) ]
    if basket.baskets_basket_complements.any?
      parts << basket_complements_description(basket.baskets_basket_complements, text_only: text_only)
    end
    parts.join(" + ").html_safe
  end

  def membership_period(membership, format: :number)
    %i[started_on ended_on].map { |d|
      I18n.l(membership.send(d), format: format)
    }.join(" – ")
  end

  def basket_size_description(object, text_only: false, public_name: true)
    case object
    when Basket, Membership
      object.basket_description(public_name: public_name)
    else
      content_tag(:em, t("activerecord.models.basket_size.none"), class: "italic text-gray-400 dark:text-gray-600") unless text_only
    end
  end

  def basket_complements_description(complements, text_only: false, public_name: true)
    complements =
      Array(complements)
        .compact
        .sort_by { |c|
          public_name ? c.basket_complement.public_name : c.basket_complement.name
        }
    names = complements.map { |c| c.description(public_name: public_name) }
    if names.present?
      names.to_sentence
    elsif !text_only
      content_tag :em, t("activerecord.models.basket_complement.none"), class: "italic text-gray-400 dark:text-gray-600"
    end
  end

  def basket_sizes_price_info(membership, baskets)
    baskets
      .billable
      .pluck(:quantity, :basket_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        "#{bbs.sum { |q, _| q }}x #{precise_cur(price).strip}"
      }.join(" + ").html_safe
  end

  def show_basket_price_extras?
    Current.org.feature?("basket_price_extra") &&
      Current.org.basket_price_extra_public_title.present? &&
      Current.org.basket_price_extras?
  end

  def show_activity_participations?
    Current.org.feature?("activity") && Current.org.activity_participations_form?
  end

  def activity_participations_form_detail(force_default: false)
    if !force_default && Current.org.activity_participations_form_detail?
      Current.org.activity_participations_form_detail
    elsif Current.org.activity_participations_form_min && Current.org.activity_participations_form_max
      t("activity_participations.form_detail.min_max", price: cur(Current.org.activity_price))
    elsif Current.org.activity_participations_form_min
      t("activity_participations.form_detail.min", price: cur(Current.org.activity_price))
    elsif Current.org.activity_participations_form_max
      t("activity_participations.form_detail.max", price: cur(Current.org.activity_price))
    end
  end

  def baskets_price_extra_info(membership, baskets, highlight: false)
    label_grouped =
      baskets
        .reject { |b| b.price_extra.zero? }
        .group_by(&:price_extra)
        .sort
    label_grouped.map { |price_extra, bbs|
      grouped =
        bbs
          .reject { |b| b.calculated_price_extra.zero? }
          .group_by(&:calculated_price_extra)
          .sort
      info = grouped.map { |calculated_price_extra, bbs|
        price = precise_cur(calculated_price_extra).strip
        "#{bbs.sum(&:quantity)}x #{price}"
      }.join(" + ")

      if Current.org.basket_price_extra_dynamic_pricing?
        label_template = Liquid::Template.parse(Current.org.basket_price_extra_label)
        label = label_template.render("extra" => price_extra).strip
        if highlight
          label = content_tag(:strong, label)
        end
        info = "#{info}, #{label}"
      end

      info
    }.join(" + ").html_safe
  end

  def membership_basket_complements_price_info(membership)
    membership.baskets
      .billable
      .joins(baskets_basket_complements: :basket_complement)
      .pluck("baskets_basket_complements.quantity", "baskets_basket_complements.price")
      .group_by { |_, price| price }
      .sort
      .map { |price, bbcs|
        "#{bbcs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def basket_complement_price_info(membership, basket_complement)
    membership.baskets
      .billable
      .joins(baskets_basket_complements: :basket_complement)
      .where(baskets_basket_complements: { basket_complement: basket_complement })
      .pluck("baskets_basket_complements.quantity", "baskets_basket_complements.price")
      .group_by { |_, price| price }
      .sort
      .map { |price, bbcs|
        "#{bbcs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def depots_price_info(baskets)
    baskets
      .billable
      .pluck(:quantity, :depot_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        "#{bbs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def delivery_cycle_price_info(baskets)
    baskets
      .billable
      .pluck(:quantity, :delivery_cycle_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        "#{bbs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def renewal_decisions_collection
    [
      [
        content_tag(:span, class: "flex flex-col") {
          content_tag(:span, t(".renewal.options.renew"),
            class: "") +
          content_tag(:span, t(".renewal.options.renew_hint"),
            class: "hint text-sm italic text-gray-400 dark:text-gray-600")
        }.html_safe,
        :renew
      ],
      [ t(".renewal.options.cancel"), :cancel ]
    ]
  end

  def display_basket_price_extra_raw(membership)
    return unless membership.basket_price_extra&.positive?

    if Current.org.basket_price_extra_dynamic_pricing?
      membership.basket_price_extra.to_i
    else
      cur(membership.basket_price_extra)
    end
  end

  private

  def precise_cur(number)
    precision = number.to_s.split(".").last.size > 2 ? 3 : 2
    cur(number, unit: false, precision: precision).strip
  end
end

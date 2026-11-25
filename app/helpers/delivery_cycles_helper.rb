# frozen_string_literal: true

module DeliveryCyclesHelper
  def delivery_cycle_link(delivery_cycle, fy_year: nil)
    return unless delivery_cycle

    count ||=
      if fy_year
        delivery_cycle.deliveries_count_for(fy_year)
      else
        delivery_cycle.deliveries_count
      end
    content_tag(:span, class: "cluster") {
      auto_link(delivery_cycle) +
        content_tag(:span, count, class: "panel-title-count text-sm").html_safe
    }
  end

  def deliveries_current_year_title
    fiscal_year = Current.org.current_fiscal_year
    "#{Delivery.model_name.human(count: 2)} (#{fiscal_year})"
  end

  def deliveries_next_year_title
    fiscal_year = Current.org.fiscal_year_for(1.year.from_now)
    "#{Delivery.model_name.human(count: 2)} (#{fiscal_year})"
  end

  def week_numbers_collection
    DeliveryCycle.week_numbers.map { |enum, _|
      [ I18n.t("delivery_cycle.week_numbers.#{enum}"), enum ]
    }
  end

  def results_collection
    col = DeliveryCycle::Period.results.map { |enum, _|
      [ I18n.t("delivery_cycle.results.#{enum}"), enum ]
    }
    # Move "all_but_first" just after "all"
    col.insert(1, col.delete_at(7))
    col
  end

  def depot_ids_with_only(delivery_cycle)
    Depot.kept.includes(:delivery_cycles).select { |d|
      d.delivery_cycle_ids.one? && d.delivery_cycle_ids.first == delivery_cycle.id
    }.map(&:id)
  end

  def fy_months_collection
    fy_start_month = Current.fiscal_year.range.min.month
    (1..12).map { |fy_month|
      calendar_month = ((fy_start_month - 1 + fy_month - 1) % 12) + 1
      name = I18n.t("date.month_names")[calendar_month].capitalize
      # Next calendar year months are marked with *
      if fy_start_month > 1 && calendar_month < fy_start_month
        name = "#{name} *"
      end
      [ name, fy_month ]
    }
  end

  def fy_month_name(fy_month)
    fy_start_month = Current.fiscal_year.range.min.month
    calendar_month = ((fy_start_month - 1 + fy_month - 1) % 12) + 1
    I18n.t("date.month_names")[calendar_month].capitalize
  end

  def fy_months_next_year_hint
    return nil if Current.fiscal_year.range.min.month == 1

    I18n.t("formtastic.hints.delivery_cycle/period.fy_months_next_year")
  end

  def displaced_basket_shifts_confirmation(shifts)
    ordered = shifts.sort_by { |shift|
      [ shift.source_delivery.date, shift.membership.member.name.to_s, shift.id ]
    }
    content_tag(:li, class: "dropped-shifts") do
      safe_join([
        content_tag(:p, class: "cluster") do
          safe_join([
            content_tag(:span, icon("triangle-alert"), class: "admin-warning-pane-icon"),
            content_tag(:span,
              t("active_admin.resources.delivery_cycle.dropped_basket_shifts_html",
                count: shifts.size))
          ])
        end,
        displaced_basket_shifts_table(ordered)
      ])
    end
  end

  def displaced_basket_shifts_table(shifts)
    content_tag(:table, class: "data-table table-auto") do
      safe_join([
        content_tag(:thead, content_tag(:tr, safe_join([
          content_tag(:th, Member.model_name.human),
          content_tag(:th, Membership.model_name.human),
          content_tag(:th, Absence.model_name.human),
          content_tag(:th, Basket.model_name.human(count: 2))
        ]))),
        content_tag(:tbody, safe_join(shifts.map { |shift| displaced_basket_shift_row(shift) }))
      ])
    end
  end

  def displaced_basket_shift_row(shift)
    content_tag(:tr, safe_join([
      content_tag(:td, auto_link(shift.membership.member)),
      content_tag(:td, auto_link(shift.membership, "##{shift.membership.id}"), class: "tabular-nums"),
      content_tag(:td, shift_absence_link(shift), class: "is-nowrap"),
      content_tag(:td, shift_baskets_label(shift), class: "is-nowrap tabular-nums")
    ]))
  end

  def shift_absence_link(shift)
    absence = shift.absence
    return "–" unless absence

    auto_link(absence, display_period(absence.started_on..absence.ended_on, format: :short))
  end

  def shift_baskets_label(shift)
    safe_join([
      shift_delivery_link(shift, shift.source_delivery),
      " → ",
      shift_delivery_link(shift, shift.target_delivery)
    ])
  end

  def shift_delivery_link(shift, delivery)
    return "–" unless delivery

    date = l(delivery.date, format: :short)
    basket = shift.membership.baskets.detect { |row| row.delivery_id == delivery.id }
    basket ? link_to(date, edit_basket_path(basket)) : auto_link(delivery, date)
  end
end

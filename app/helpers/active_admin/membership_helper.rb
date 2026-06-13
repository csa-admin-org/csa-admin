# frozen_string_literal: true

module ActiveAdmin::MembershipHelper
  def renew_button(arbre, membership)
    if authorized?(:renew, membership)
      arbre.div do
        panel_button t("active_admin.resource.show.renew"), renew_membership_path(membership),
          icon: "refresh-cw",
          disabled: !membership.can_renew?,
          disabled_tooltip: t("active_admin.resource.show.renew_no_future_deliveries"),
          data: { confirm: t("active_admin.resource.show.confirm") }
      end
    end
  end

  def cancel_renewal_buttons(arbre, membership)
    if authorized?(:cancel, membership)
      arbre.div do
        panel_button t("active_admin.resource.show.cancel_renewal"), cancel_membership_path(membership),
          icon: "circle-x",
          class: "btn btn-sm destructive",
          data: { confirm: t("active_admin.resource.show.confirm") }
      end
    end
    if Current.org.feature?("annual_fee") && authorized?(:cancel_keep_support, membership)
      arbre.div do
        panel_button t("active_admin.resource.show.cancel_renewal_keep_support"), cancel_keep_support_membership_path(membership),
          icon: "circle-x",
          class: "btn btn-sm destructive",
          data: { confirm: t("active_admin.resource.show.confirm") }
      end
    end
  end

  def basket_config_rows(arbre, describable, complements_association)
    arbre.row(:basket_size) { basket_size_description(describable, text_only: true, public_name: false) }
    if BasketComplement.kept.any?
      arbre.row(Membership.human_attribute_name(:memberships_basket_complements)) {
        basket_complements_description(complements_association, text_only: true, public_name: false)
      }
    end
  end

  def waiting_member_position(member)
    waiting_member_positions[member.id]
  end

  def waiting_membership_action_notice(member)
    if member.pending? && member.membership_request?
      waiting_membership_validation_notice(member)
    elsif member.waiting?
      waiting_membership_activation_notice(member)
    end
  end

  def waiting_membership_action_notice_class(member)
    if member.validation_waiting_membership_no_delivery? || member.activation_waiting_membership_no_delivery?
      "mb-2 text-center italic text-red-600 dark:text-red-400"
    else
      "mb-2 text-center italic text-gray-500 dark:text-gray-400"
    end
  end

  private

  def waiting_member_positions
    @waiting_member_positions ||= Member.waiting
      .order(:waiting_started_at, :id)
      .pluck(:id)
      .each.with_index(1)
      .to_h
  end

  def waiting_membership_validation_notice(member)
    if Current.org.waiting_list? && !member.direct_membership_start_requested?
      t("active_admin.resource.show.membership_validation_waiting_list")
    elsif start_on = member.waiting_membership_start_on
      t("active_admin.resource.show.membership_validation_start_on", date: l(start_on))
    else
      t("active_admin.resource.show.membership_validation_no_delivery")
    end
  end

  def waiting_membership_activation_notice(member)
    if start_on = member.waiting_delivery_cycle_next_start_on
      t("active_admin.resource.show.membership_activation_start_on", date: l(start_on))
    else
      t("active_admin.resource.show.membership_activation_no_delivery")
    end
  end
end

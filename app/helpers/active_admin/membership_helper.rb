# frozen_string_literal: true

module ActiveAdmin::MembershipHelper
  def renew_button(arbre, membership)
    if authorized?(:renew, membership)
      arbre.div do
        panel_button t("active_admin.resource.show.renew"), renew_membership_path(membership),
          icon: "arrow-path",
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
          icon: "x-circle",
          class: "btn btn-sm destructive",
          data: { confirm: t("active_admin.resource.show.confirm") }
      end
    end
    if Current.org.annual_fee? && authorized?(:cancel_keep_support, membership)
      arbre.div do
        panel_button t("active_admin.resource.show.cancel_renewal_keep_support"), cancel_keep_support_membership_path(membership),
          icon: "x-circle",
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
end

# frozen_string_literal: true

ActiveAdmin.register Audit, as: "DeliveryAudit" do
  extend AuditsIndex
  audits_for Delivery

  breadcrumb do
    links = [
      link_to(Delivery.model_name.human(count: 2), deliveries_path),
      auto_link(parent)
    ]
    links
  end
end

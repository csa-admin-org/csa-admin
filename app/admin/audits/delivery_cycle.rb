# frozen_string_literal: true

ActiveAdmin.register Audit, as: "DeliveryCycleAudit" do
  extend AuditsIndex
  audits_for DeliveryCycle

  breadcrumb do
    links = [
      link_to(Delivery.model_name.human(count: 2), deliveries_path),
      link_to(DeliveryCycle.model_name.human(count: 2), delivery_cycles_path),
      auto_link(parent)
    ]
    links
  end
end

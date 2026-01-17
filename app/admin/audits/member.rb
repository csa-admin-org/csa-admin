# frozen_string_literal: true

ActiveAdmin.register Audit, as: "MemberAudit" do
  extend AuditsIndex
  audits_for Member

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(parent)
    ]
    links
  end
end

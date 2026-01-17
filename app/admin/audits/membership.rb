# frozen_string_literal: true

ActiveAdmin.register Audit, as: "MembershipAudit" do
  extend AuditsIndex
  audits_for Membership

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(parent.member),
      link_to(
        Membership.model_name.human(count: 2),
        memberships_path(q: { member_id_eq: parent.member_id }, scope: :all)),
      auto_link(parent)
    ]
    links
  end
end

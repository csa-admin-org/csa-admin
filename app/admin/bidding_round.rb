# frozen_string_literal: true

ActiveAdmin.register BiddingRound do
  menu parent: :other, priority: 9
  actions :all

  scope :all, default: true
  scope :draft
  scope :open
  scope :completed
  scope :failed

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  index(download_links: false) do
    column :title
    column(t("active_admin.resource.show.pledges_percentage"), class: "text-right tabular-nums") do |br|
      number_to_percentage br.pledges_percentage, precision: 0
    end
    column(t("active_admin.resource.show.total_pledged_percentage"), class: "text-right tabular-nums") do |br|
      number_to_percentage br.pledges_percentage, precision: 0
    end
    column(:state, class: "text-right") { |br| status_tag(br.state, label: br.state_i18n_name) }
    actions
  end

  sidebar :no_eligible_memberships, only: :index, if: -> { BiddingRound.new.eligible_memberships.none? } do
    side_panel t(".no_eligible_memberships"), action: handbook_icon_link("bidding_round", anchor: "requirements"), class: "warning" do
      para do
        t(".no_eligible_memberships_text", year: BiddingRound.fiscal_year.to_s)
      end
    end
  end

  sidebar_handbook_link("bidding_round")

  form do |f|
    if f.object.errors.any?
      div class: "mb-6" do
        f.object.errors.attribute_names.each do |attr|
          para f.semantic_errors attr
        end
      end
    end

    f.inputs t(".details") do
      f.input :title, input_html: { disabled: true }

      translated_input(f, :information_texts,
        as: :action_text,
        input_html: { rows: 5 },
        hint: t("formtastic.hints.bidding_round.information_text"))
    end
    f.actions
  end

  show do |bidding_round|
    columns do
      column do
        panel nil do
          ul class: "grid grid-cols-2 gap-4 m-4 " do
            li do
              counter_tag(t(".eligible_memberships").capitalize, bidding_round.eligible_memberships_count)
            end
            li do
              counter_tag(t(".total_expected_value").capitalize, bidding_round.total_expected_value, type: :currency)
            end
            li do
              counter_tag(t(".pledges_count").capitalize, bidding_round.pledges_count)
            end
            li do
              counter_tag(t(".total_pledged_value").capitalize, bidding_round.total_pledged_value, type: :currency)
            end
            li do
              counter_tag(t(".pledges_percentage").capitalize, bidding_round.pledges_percentage, type: :percentage)
            end
            li do
              counter_tag(t(".total_pledged_percentage").capitalize, bidding_round.total_pledged_percentage, type: :percentage)
            end
          end
        end
      end

      column do
        panel t(".details") do
          attributes_table do
            row(:created_at)
            unless bidding_round.draft?
              row(:opened_by)
              row(:opened_at)
            end
          end
        end
        panel BiddingRound.human_attribute_name(:information_text) do
          div class: "px-2 mb-2" do
            para bidding_round.information_text
          end
        end
      end
    end
  end

  action_item :open, only: :show, if: -> { authorized?(:open, resource) } do
    action_button t(".open"), open_bidding_round_path(resource),
      data: { confirm: t(".bidding_round.open_confirm", count: resource.eligible_memberships_count) },
      icon: "play"
  end

  action_item :complete, only: :show, if: -> { authorized?(:complete, resource) } do
    action_button t(".complete"), complete_bidding_round_path(resource),
      data: { confirm: t(".bidding_round.complete_confirm", count: resource.eligible_memberships_count) },
      icon: "circle-check-big"
  end

  action_item :fail, only: :show, if: -> { authorized?(:fail, resource) } do
    action_button t(".fail"), fail_bidding_round_path(resource),
      data: { confirm: t(".bidding_round.fail_confirm", count: resource.eligible_memberships_count) },
      icon: "circle-off",
      class: "destructive"
  end

  member_action :open, method: :post do
    resource.open!
    redirect_to resource_path
  end

  member_action :complete, method: :post do
    resource.complete!
    redirect_to resource_path
  end

  member_action :fail, method: :post do
    resource.fail!
    redirect_to resource_path
  end

  permit_params(*I18n.available_locales.map { |l| "information_text_#{l}" })
end

# frozen_string_literal: true

class Newsletter
  module Audience
    include ActivitiesHelper

    extend self
    CIPHER_KEY = "aes-256-cbc"

    def encrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).encrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secret_key_base)
      s = cipher.update(email) + cipher.final
      s.unpack("H*")[0].downcase
    end

    def decrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).decrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secret_key_base)
      s = [ email ].pack("H*").unpack("C*").pack("c*")
      cipher.update(s) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      nil
    end

    def name(segment)
      "#{segment_name(segment.key)}: #{segment.name}"
    end

    def segment_name(key)
      case key
      when :segment_id; I18n.t("newsletters.segment.title")
      when :basket_size_id; BasketSize.model_name.human
      when :basket_complement_id; BasketComplement.model_name.human
      when :depot_id; Depot.model_name.human
      when :delivery_id; ::Delivery.model_name.human
      when :member_state; Member.model_name.human(count: 2)
      when :membership_state; Membership.model_name.human(count: 2)
      when :invoice_state; Invoice.model_name.human(count: 2)
      when :activity_state; activities_human_name
      when :activity_id; Activity.model_name.human
      when :shop_delivery_gid
        Shop::Order.model_name.human(count: 2) + " (#{I18n.t('shop.title')})"
      when :bidding_round_pledge_presence
        BiddingRound.model_name.human + " (#{BiddingRound.state_i18n_name(:open)})"
      end
    end

    class Segment < Struct.new(:key, :value, :name)
      def self.parse(audience)
        key, value = audience.split("::", 2)
        Segment.new(key.to_sym, value)
      end

      def record
        Audience.record_for(key, value)
      end

      def name
        super || record&.name || I18n.t("newsletters.segment_unknown")
      end

      def id
        "#{key}::#{value}"
      end

      def emails
        @emails ||= (all_emails - suppressed_emails).uniq
      end

      def suppressed_emails
        @suppressed_emails ||=
          EmailSuppression.active.where(email: all_emails).pluck(:email).uniq
      end

      def members
        case key
        when :segment_id
          segment = Newsletter::Segment.find_by(id: value)
          segment&.members || []
        when :basket_size_id
          Member
            .joins(:current_or_future_membership)
            .where(memberships: { basket_size_id: value })
            .distinct
        when :basket_complement_id
          Member
            .joins(current_or_future_membership: :memberships_basket_complements)
            .where(memberships_basket_complements: { basket_complement_id: value })
            .distinct
        when :depot_id
          Member
            .joins(:current_or_future_membership)
            .where(memberships: { depot_id: value })
            .distinct
        when :delivery_id
          delivery_id = GlobalID.new(value).model_id
          Member
            .joins(:baskets)
            .merge(Basket.unscoped.deliverable)
            .where(baskets: { delivery_id: delivery_id })
            .distinct
        when :member_id
          Member.where(id: value)
        when :member_state
          case value
          when "all"; Member.not_pending
          when "not_inactive"; Member.not_pending.not_inactive
          else; Member.where(state: value)
          end
        when :membership_state
          Member.joins(:memberships).merge(Membership.send(value)).distinct
        when :invoice_state
          case value
          when "open"
            Member.joins(:invoices).merge(Invoice.open.sent).distinct
          when "open_with_overdue_notice"
            Member.joins(:invoices).merge(Invoice.sent.with_overdue_notice).distinct
          end
        when :activity_state
          case value
          when "demanded"
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1.. })
              .distinct
          when "missing"
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1.. })
              .where("activity_participations_demanded > activity_participations_accepted")
              .distinct
          end
        when :activity_id
          Member
            .joins(:activity_participations)
            .where(activity_participations: { activity_id: value })
            .distinct
        when :shop_delivery_gid
          Member
            .joins(:shop_orders)
            .merge(Shop::Order.all_without_cart._delivery_gid_eq(value))
            .distinct
        when :bidding_round_pledge_presence
          bidding_round = BiddingRound.current_open
          return Member.none unless bidding_round

          member_ids_with_pledge = bidding_round.pledges.joins(:membership).select(:member_id)
          case value
          when "true"
            Member.where(id: member_ids_with_pledge)
          when "false"
            member_ids = bidding_round.eligible_memberships.select(:member_id)
            Member.where(id: member_ids).where.not(id: member_ids_with_pledge)
          end
        end
      end

      private

      def all_emails
        @all_emails ||= members.flat_map(&:emails_array)
      end
    end

    def record_for(key, value)
      case key
      when :segment_id; Newsletter::Segment.find_by(id: value)
      when :basket_size_id; BasketSize.find_by(id: value)
      when :basket_complement_id; BasketComplement.find_by(id: value)
      when :depot_id; Depot.find_by(id: value)
      when :member_state
        name =
          if Member::STATES.include?(value)
            I18n.t("states.member.#{value}").capitalize
          else
            I18n.t("newsletters.member_state.#{value}")
          end
        OpenStruct.new(id: value, name: name)
      when :membership_state
        OpenStruct.new(id: value, name: I18n.t("states.membership.#{value}").capitalize)
      when :invoice_state
        OpenStruct.new(
          id: value,
          name: I18n.t("states.invoice.#{value}").capitalize)
      when :activity_state
        OpenStruct.new(
          id: value,
          name: I18n.t("newsletters.activity_state.#{value}"))
      when :activity_id; Activity.find_by(id: value)
      when :shop_delivery_gid, :delivery_id
        GlobalID::Locator.locate(value)
      when :bidding_round_pledge_presence
        OpenStruct.new(
          id: value,
          name: I18n.t("bidding_rounds.pledge_presence.#{value}"))
      end
    end

    def segments
      base = {
        segment_id: Newsletter::Segment.order_by_title,
        member_state: member_state_records.sort_by(&:name),
        membership_state: membership_state_records.sort_by(&:name),
        delivery_id: ::Delivery.between(1.week.ago..).limit(8),
        depot_id: Depot.used.order_by_name,
        basket_size_id: BasketSize.used.ordered
      }
      if BasketComplement.kept.any?
        base[:basket_complement_id] = BasketComplement.used.ordered
      end
      base[:invoice_state] = invoice_state_records.sort_by(&:name)
      if Current.org.feature?("shop")
        base[:shop_delivery_gid] = (
          ::Delivery
            .between(1.week.ago..)
            .joins(:shop_orders)
            .merge(Shop::Order.all_without_cart)
            .distinct
            .limit(8) +
          Shop::SpecialDelivery
            .between(1.week.ago..)
            .joins(:shop_orders)
            .merge(Shop::Order.all_without_cart)
            .distinct
            .limit(8)
        ).sort_by(&:date).first(8)
      end
      if Current.org.feature?("activity")
        base[:activity_state] = activity_state_records
        base[:activity_id] =
          Activity.joins(:participations).coming.limit(12).distinct.order(:date)
      end
      if Current.org.feature?("bidding_round")
        base[:bidding_round_pledge_presence] = [
          record_for(:bidding_round_pledge_presence, true),
          record_for(:bidding_round_pledge_presence, false)
        ]
      end
      base.map { |key, records|
        [
          key,
          records.map { |r|
            value = r.respond_to?(:gid) ? r.gid : r.id
            Segment.new(key, value, r.name)
          }
        ]
      }.select { |_, segments| segments.any? }.to_h
    end

    def member_state_records
      states = Member::STATES - %w[pending]
      states -= %w[support] unless Current.org.member_support?
      states += %w[all not_inactive]
      states.map { |s| record_for(:member_state, s) }
    end

    def membership_state_records
      states = []
      states << "trial" if Current.org.trial_baskets?
      states += [ "ongoing", "future", "past" ]
      states.map { |s| record_for(:membership_state, s) }
    end

    def invoice_state_records
      states = %w[open open_with_overdue_notice]
      states.map { |s| record_for(:invoice_state, s) }
    end

    def activity_state_records
      states = %w[demanded missing]
      states.map { |s| record_for(:activity_state, s) }
    end
  end
end

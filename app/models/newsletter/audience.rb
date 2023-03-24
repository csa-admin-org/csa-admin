class Newsletter
  module Audience
    extend self
    CIPHER_KEY = 'aes-256-cbc'

    def encrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).encrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secrets.secret_key_base)
      s = cipher.update(email) + cipher.final
      s.unpack('H*')[0].downcase
    end

    def decrypt_email(email)
      cipher = OpenSSL::Cipher.new(CIPHER_KEY).decrypt
      cipher.key = Digest::MD5.hexdigest(Rails.application.secrets.secret_key_base)
      s = [email].pack("H*").unpack("C*").pack("c*")
      cipher.update(s) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      nil
    end

    class Segment < Struct.new(:key, :value, :name)
      def self.parse(audience)
        key, value = audience.split('::')
        Segment.new(key.to_sym, value)
      end

      def record
        Audience.record_for(key, value)
      end

      def name
        super || record&.name || I18n.t('newsletters.segment_unknown')
      end

      def id
        "#{key}::#{value}"
      end

      def emails
        @emails ||= (all_emails - suppressed_emails).uniq
      end

      def suppressed_emails
        @suppressed_emails ||=
          EmailSuppression.broadcast.active.where(email: all_emails).pluck(:email).uniq
      end

      def members
        case key
        when :basket_size_id
          Member
            .joins(:current_membership)
            .where(memberships: { basket_size_id: value })
        when :basket_complement_id
          Member
            .joins(current_membership: :memberships_basket_complements)
            .where(memberships_basket_complements: { basket_complement_id: value })
        when :depot_id
          Member
            .joins(:current_membership)
            .where(memberships: { depot_id: value })
        when :delivery_id
          delivery_id = GlobalID.new(value).model_id
          Member
            .joins(:baskets)
            .where(baskets: { delivery_id: delivery_id })
        when :member_id
          Member.where(id: value)
        when :member_state
          case value
          when 'all'; Member.not_pending
          when 'not_inactive'; Member.not_pending.not_inactive
          when 'waiting_active'; Member.where(state: %w[waiting active])
          else; Member.where(state: value)
          end
        when :invoice_state
          case value
          when 'open'
            Member.joins(:invoices).merge(Invoice.open.sent).distinct
          when 'open_with_overdue_notice'
            Member.joins(:invoices).merge(Invoice.sent.with_overdue_notice).distinct
          end
        when :activity_state
          case value
          when 'demanded'
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1..})
          when 'missing'
            Member
              .joins(:current_year_membership)
              .where(memberships: { activity_participations_demanded: 1..})
              .where('activity_participations_demanded > activity_participations_accepted')
          end
        when :activity_id
          Member
            .joins(:activity_participations)
            .where(activity_participations: { activity_id: value })
        when :shop_delivery_gid
          Member
            .joins(:shop_orders)
            .merge(Shop::Order.all_without_cart._delivery_gid_eq(value))
        end
      end

      private

      def all_emails
        @all_emails ||= members.flat_map(&:emails_array)
      end
    end

    def record_for(key, value)
      case key
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
      end
    end

    def segments
      base = {
        member_state: member_state_records.sort_by(&:name),
        delivery_id: ::Delivery.between(1.week.ago..).limit(8),
        depot_id: Depot.used.reorder(:name),
        basket_size_id: BasketSize.used,
      }
      if BasketComplement.any?
        base[:basket_complement_id] = BasketComplement.used
      end
      base[:invoice_state] = invoice_state_records.sort_by(&:name)
      if Current.acp.feature?('shop')
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
      if Current.acp.feature?('activity')
        base[:activity_state] = activity_state_records
        base[:activity_id] =
          Activity.joins(:participations).coming.limit(12).distinct.order(:date)
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
      states += %w[all not_inactive waiting_active]
      states.map { |s| record_for(:member_state, s) }
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

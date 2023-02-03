require 'rubygems/package'

class Mailchimp
  include ActivitiesHelper

  BatchError = Class.new(StandardError)

  def self.sync_list
    return if Rails.env.development?
    return unless mailchimp_credentials = Current.acp.credentials(:mailchimp)

    mailchimp = new(mailchimp_credentials)
    I18n.with_locale(Current.acp.default_locale) do
      mailchimp.upsert_merge_fields
      mailchimp.upsert_members(Member.all)
      mailchimp.unsubscribe_deleted_members(Member.all)
      mailchimp.sync_unsubscribed_members(Member.all)
    end
  rescue Gibbon::MailChimpError => e
    Sentry.capture_exception(e)
  end

  def initialize(credentials)
    @credentials = credentials
    @list_id = credentials.fetch(:list_id)
  end

  def upsert_members(members)
    operations = []
    members.find_each do |member|
      next if !member.active? && member.updated_at < 3.days.ago

      member.emails_array.each do |email|
        next if email_suppressed?(email)

        hash_id = hash_id(email)
        body = {
          email_address: email,
          merge_fields: member_merge_fields(member)
        }
        body[:status] = 'subscribed' unless hash_id.in?(hash_ids)
        operations << {
          method: 'PUT',
          path: "lists/#{@list_id}/members/#{hash_id}",
          body: JSON(body)
        }
      end
    end
    res = client.batches.create(body: { operations: operations })
    Rails.logger.info "Mailchimp batch #{res.body[:id]} created"
    ensure_batch_succeed!(res.body[:id])
  end

  def unsubscribe_deleted_members(members)
    hash_ids_and_emails = hash_ids_and_emails(members)
    mailchimp_hash_ids_and_emails = get_hash_ids_and_emails
    hash_ids_to_delete = mailchimp_hash_ids_and_emails.keys - hash_ids_and_emails.keys
    hash_ids_to_delete.each do |hash_id|
      client.lists(@list_id).members(hash_id).update(body: { status: 'unsubscribed' })
    rescue Gibbon::MailChimpError => e
      Sentry.capture_exception(e, extra: {
        email: mailchimp_hash_ids_and_emails[hash_id],
        hash_id: hash_id
      })
    end
  end

  def sync_unsubscribed_members(members)
    hash_ids_and_emails = hash_ids_and_emails(members)
    mailchimp_hash_ids_and_emails = get_hash_ids_and_emails(status: 'unsubscribed')
    unsubscribed_hash_ids = mailchimp_hash_ids_and_emails.keys & hash_ids_and_emails.keys
    context = { stream_id: 'broadcast', origin: 'Mailchimp' }
    unsuppressable_emails = EmailSuppression.unsuppressable.where(context).pluck(:email)
    hash_ids_and_emails.each do |hash_id, email|
      if unsubscribed_hash_ids.include?(hash_id)
        EmailSuppression.suppress!(email, **context.merge(reason: 'ManualSuppression')
      elsif unsuppressable_emails.include?(email)
        EmailSuppression.unsuppress!(email, **context)
      end
    end
  end

  def upsert_merge_fields
    fields = {
      MEMB_ID:   { name: 'ID', type: 'number', required: false },
      MEMB_NAME: { name: t('name'), type: 'text', required: false },
      MEMB_LANG: { name: t('language'), type: 'text', required: false },
      MEMB_STAT: { name: t('status'), type: 'dropdown', required: false, options: { choices: Member::STATES } },
      CURR_MEMB: { name: t('membership_ongoing'), type: 'dropdown', required: false, options: { choices: %w[yes no] } },
      MEMB_RNEW: { name: t('membership_renewed'), type: 'dropdown', required: false, options: { choices: %w[yes no –] } },
      BASK_FIRS: { name: t('first_basket_date'), type: 'text', required: false },
      BASK_DATE: { name: t('next_basket_date'), type: 'text', required: false },
      BASK_DELI: { name: t('next_basket_delivered'), type: 'dropdown', required: false, options: { choices: %w[yes no] } },
      BASK_SIZE: { name: t('basket_size'), type: 'dropdown', required: false, options: { choices: BasketSize.all.map(&:name) } },
      BASK_DIST: { name: t('depot'), type: 'dropdown', required: false, options: { choices: Depot.order(:name).pluck(:name) } }
    }
    if Current.acp.feature?(:activity)
      fields[:HALF_ASKE] = { name: "#{activities_human_name} demandées", type: 'number', required: false }
      fields[:HALF_ACPT] = { name: "#{activities_human_name} acceptées", type: 'number', required: false }
      fields[:HALF_MISS] = { name: "#{activities_human_name} manquantes", type: 'number', required: false }
    end
    if Current.acp.feature?(:group_buying)
      fields[:GRBY_NEXT] = { name: 'Achats Groupés, prochaine livraison commandée', type: 'dropdown', required: false, options: { choices: %w[yes no –] } }
      fields[:GRBY_DATE] = { name: 'Achats Groupés, date dernière livraison commandée', type: 'text', required: false }
    end
    if BasketComplement.any?
      fields[:BASK_COMP] = { name: 'Compléments panier', type: 'text', required: false }
    end
    if Current.acp.trial_basket_count.positive?
      fields[:BASK_TRIA] = { name: "Nombre de paniers à l'essai restant", type: 'number', required: false }
    end
    exiting_fields =
      client.lists(@list_id).merge_fields
        .retrieve(params: { fields: 'merge_fields.tag,merge_fields.merge_id', count: 100 })
        .body[:merge_fields].map { |m| [m[:tag], m[:merge_id]] }.to_h
    fields.each do |tag, attrs|
      attrs[:tag] = tag.to_s
      attrs[:public] = false
      if id = exiting_fields[tag.to_s]
        client.lists(@list_id).merge_fields(id).update(body: attrs)
      else
        client.lists(@list_id).merge_fields.create(body: attrs)
      end
    end
  end

  private

  def client
    @client ||= Gibbon::Request.new(
      api_key: @credentials.fetch(:api_key),
      symbolize_keys: true)
  end

  def email_suppressed?(email)
    @suppressed_emails ||= EmailSuppression.active.broadcast.pluck(:email)
    @suppressed_emails.include?(email)
  end

  def hash_id(email)
    Digest::MD5.hexdigest(email.downcase)
  end

  def hash_ids_and_emails(members)
    members.select(:emails).flat_map(&:emails_array).map { |e|
      [hash_id(e), e]
    }.to_h
  end

  def hash_ids
    @hash_ids ||= get_hash_ids_and_emails.keys
  end

  def get_hash_ids_and_emails(status: nil)
    params = { fields: 'members.email_address,members.id', count: 2000 }
    params[:status] = status if status
    client.lists(@list_id).members.retrieve(params: params).body[:members].map { |m|
      [m[:id], m[:email_address]]
    }.to_h
  end

  def member_merge_fields(member)
    current_year_membership = member.current_year_membership
    first_basket = member.first_membership&.baskets&.first
    next_basket = member.next_basket
    @next_delivery ||= Delivery.next
    fields = {
      MEMB_ID: member.id,
      MEMB_NAME: member.name,
      MEMB_LANG: member.language,
      MEMB_STAT: member.state,
      CURR_MEMB: member.current_membership ? 'yes' : 'no',
      MEMB_RNEW: current_year_membership ? (current_year_membership.renew? ? 'yes' : 'no') : '–',
      BASK_FIRS: (first_basket && I18n.l(first_basket&.delivery&.date, locale: member.language)).to_s,
      BASK_DATE: (next_basket && I18n.l(next_basket&.delivery&.date, locale: member.language)).to_s,
      BASK_DELI: @next_delivery && next_basket && !next_basket.absent? && next_basket.delivery == @next_delivery ? 'yes' : 'no',
      BASK_SIZE: next_basket&.basket_size&.name.to_s,
      BASK_DIST: next_basket&.depot&.name.to_s
    }
    if Current.acp.feature?(:activity)
      fields[:HALF_ASKE] = current_year_membership&.activity_participations_demanded.to_i
      fields[:HALF_ACPT] = current_year_membership&.activity_participations_accepted.to_i
      fields[:HALF_MISS] = current_year_membership&.missing_activity_participations.to_i
    end
    if Current.acp.feature?(:group_buying)
      @next_group_buying_delivery ||= GroupBuying::Delivery.next
      fields[:GRBY_NEXT] =
        if @next_group_buying_delivery
          @next_group_buying_delivery.orders.exists?(member_id: member.id) ? 'yes' : 'no'
        else
          '–'
        end
      last_order_date =
        member.group_buying_orders.joins(:delivery).maximum('group_buying_deliveries.date')
      fields[:GRBY_DATE] = (last_order_date && I18n.l(last_order_date, locale: member.language)).to_s
    end
    if BasketComplement.any?
      fields[:BASK_COMP] =
        next_basket&.membership&.subscribed_basket_complements&.map(&:name)&.join(', ').to_s
    end
    if Current.acp.trial_basket_count.positive?
      fields[:BASK_TRIA] = current_year_membership&.remaning_trial_baskets_count.to_i
    end
    fields
  end

  def ensure_batch_succeed!(batch_id, retry_count: 10)
    error = nil
    sleep 10
    res = client.batches(batch_id).retrieve
    if res.body[:status] != 'finished'
      if retry_count > 0
        ensure_batch_succeed!(res.body[:id], retry_count: retry_count - 1)
        Rails.logger.info "Mailchimp batch #{batch_id} finished"
      else
        Rails.logger.info "Mailchimp batch #{batch_id} is not finished yet"
      end
    elsif res.body[:errored_operations].positive?
      suppress_emails(res)
    end
  end

  def suppress_emails(res)
    results = get_batch_results(res)
    results.each do |r|
      if r['status_code'] == 400
        json = JSON.load(r['response'])
        if json['title'] == 'Forgotten Email Not Subscribed'
          email = json['detail'].split(' ').first
          EmailSuppression.suppress!(email,
            stream_id: 'broadcast',
            origin: 'Mailchimp',
            reason: 'Forgotten')
        else
          Sentry.capture_message('Unknown Mailchimp batch error (400) title', extra: {
            title: json['title'],
            json: json
          })
        end
      elsif r['status_code'] != 200
        Sentry.capture_message('Unknown Mailchimp batch status_code', extra: {
          status_code: r['status_code'],
          result: r
        })
      end
    end
  end

  def get_batch_results(res)
    error_url = res.body[:response_body_url]
    results = nil
    targz = Gem::Package::TarReader.new(Zlib::GzipReader.new(URI.open(error_url)))
    targz.each do |entry|
      if entry.file?
        results = JSON.load(entry.read)
      end
    end
    results
  end

  def t(key)
    I18n.t(key, scope: 'mailchimp.merge_fields')
  end
end

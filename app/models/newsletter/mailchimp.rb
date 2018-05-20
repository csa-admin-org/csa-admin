class Newsletter::MailChimp
  include HalfdaysHelper

  BatchError = Class.new(StandardError)

  def initialize(credentials)
    @credentials = credentials
    @list_id = credentials.fetch(:list_id)
  end

  def upsert_members(members)
    operations = []
    members.find_each do |member|
      member.emails_array.each do |email|
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
    ensure_batch_succeed!(res.body[:id])
  end

  def remove_deleted_members(members)
    member_hash_ids =
      members.select(:emails).flat_map(&:emails_array).map { |e| hash_id(e) }
    hash_ids_to_delete = get_hash_ids - member_hash_ids
    hash_ids_to_delete.each do |hash_id|
      client.lists(@list_id).members(hash_id).delete
    end
  end

  def upsert_merge_fields
    fields = {
      MEMB_ID:   { name: 'ID', type: 'number', required: true },
      MEMB_NAME: { name: 'Nom', type: 'text', required: true },
      MEMB_LANG: { name: 'Langue', type: 'text', required: true },
      MEMB_NEWS: { name: 'Newsletter envoyée?', type: 'dropdown', required: true, options: { choices: %w[yes no] } },
      MEMB_STAT: { name: 'Status', type: 'dropdown', required: true, options: { choices: Member::STATES } },
      MEMB_PAGE: { name: 'Page de membre URL', type: 'text', required: true },
      BASK_DATE: { name: 'Date du prochain panier', type: 'text', required: false },
      BASK_SIZE: { name: 'Taille panier', type: 'dropdown', required: false, options: { choices: [nil] + BasketSize.order(:name).pluck(:name) } },
      BASK_DIST: { name: 'Distribution', type: 'dropdown', required: false, options: { choices: [nil] + Distribution.order(:name).pluck(:name) } },
      HALF_ASKE: { name: "#{halfdays_human_name} demandées", type: 'number', required: true },
      HALF_MISS: { name: "#{halfdays_human_name} manquantes", type: 'number', required: true }
    }
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

  def hash_id(email)
    Digest::MD5.hexdigest(email.downcase)
  end

  def hash_ids
    @hash_ids ||= get_hash_ids
  end

  def get_hash_ids(status: nil)
    params = { fields: 'members.id', count: 2000 }
    params[:status] = status if status
    client.lists(@list_id).members.retrieve(params: params)
      .body[:members].map { |m| m[:id] }
  end

  def member_merge_fields(member)
    fields = {
      MEMB_ID: member.id,
      MEMB_NAME: member.name,
      MEMB_LANG: member.language,
      MEMB_NEWS: member.newsletter? ? 'yes' : 'no',
      MEMB_STAT: member.state,
      MEMB_PAGE: member.page_url,
      BASK_DATE: (member.next_basket && I18n.l(member.next_basket&.delivery&.date, locale: member.language)).to_s,
      BASK_SIZE: member.next_basket&.basket_size&.name.to_s,
      BASK_DIST: member.next_basket&.distribution&.name.to_s,
      HALF_ASKE: member.current_year_membership&.halfday_works.to_i,
      HALF_MISS: member.current_year_membership&.missing_halfday_works.to_i
    }
    if BasketComplement.any?
      fields[:BASK_COMP] =
        member.next_basket&.membership&.subscribed_basket_complements&.map(&:name)&.join(', ').to_s
    end
    if Current.acp.trial_basket_count.positive?
      fields[:BASK_TRIA] = member.current_year_membership&.remaning_trial_baskets_count.to_i
    end
    fields
  end

  def ensure_batch_succeed!(batch_id)
    sleep 2
    res = client.batches(batch_id).retrieve
    if res.body[:status] != 'finished'
      ensure_batch_succeed!(res.body[:id])
    elsif res.body[:errored_operations].positive?
      raise BatchError,
        "MailChimp Batch #{batch_id} failed with response: #{res.body[:response_body_url]}"
    end
  end
end

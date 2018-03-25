class Newsletter::MailChimp
  include HalfdaysHelper

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
    client.batches.create(body: { operations: operations })
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
      MEMB_STAT: { name: 'Status', type: 'dropdown', required: true, options: { choices: Member.state_i18n_names } },
      MEMB_PAGE: { name: 'Page de membre URL', type: 'url', required: true },
      BASK_SIZE: { name: 'Taille panier', type: 'dropdown', required: false, options: { choices: BasketSize.order(:name).pluck(:name) } },
      BASK_DIST: { name: 'Distribution', type: 'dropdown', required: false, options: { choices: Distribution.order(:name).pluck(:name) } },
      BASK_COMP: { name: 'Compléments panier', type: 'text', required: false },
      HALF_ASKE: { name: "#{halfdays_human_name} demandées", type: 'number', required: true },
      HALF_VALI: { name: "#{halfdays_human_name} validées", type: 'number', required: true },
      HALF_COMI: { name: "#{halfdays_human_name} à venir", type: 'number', required: true },
      HALF_MISS: { name: "#{halfdays_human_name} manquantes", type: 'number', required: true }
    }
    exiting_fields =
      client.lists(@list_id).merge_fields
        .retrieve(params: { fields: 'merge_fields.tag,merge_fields.merge_id', count: 100 })
        .body[:merge_fields].map { |m| [m[:tag], m[:merge_id]] }.to_h
    fields.each do |tag, attrs|
      attrs.merge!(tag: tag.to_s, public: false)
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
      MEMB_STAT: member.state_i18n_name,
      MEMB_PAGE: [Current.acp.email_default_host, member.token].join('/')
    }
    if membership = (member.current_year_membership || member.future_membership)
      halfday_asked = member.halfday_works(membership.fiscal_year)
      halfday_validated = member.validated_halfday_works(membership.fiscal_year)
      halfday_coming = member.coming_halfday_works(membership.fiscal_year)
      fields[:HALF_ASKE] = halfday_asked
      fields[:HALF_VALI] = halfday_validated
      fields[:HALF_COMI] = halfday_coming
      fields[:HALF_MISS] = halfday_asked - halfday_validated - halfday_coming
    end
    if basket = member.baskets.coming.first
      fields[:BASK_SIZE] = basket.basket_size&.name
      fields[:BASK_DIST] = basket.distribution.name
      fields[:BASK_COMP] = basket.membership.subscribed_basket_complements.map(&:name).join(', ')
    end
    fields
  end
end

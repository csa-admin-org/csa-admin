class Members::Shop::BaseController < Members::BaseController
  before_action :ensure_shop_feature
  before_action :ensure_delivery

  private

  def ensure_shop_feature
    redirect_to members_member_path unless Current.acp.feature?('shop')
  end

  def ensure_delivery
    unless delivery
      redirect_to members_member_path
    end
  end

  def shop_path
    case @order&.delivery
    when next_shop_delivery; members_shop_next_path
    when Shop::SpecialDelivery; members_shop_special_delivery_path(@order.delivery.date)
    else members_shop_path
    end
  end
  helper_method :shop_path

  def available_products
    @available_products ||= all_available_products
  end
  helper_method :available_products

  def available_producers
    @available_producers ||=
      all_available_products(params.slice(:tag_id))
        .map(&:producer)
        .compact
        .uniq
        .sort_by(&:name) - [Shop::NullProducer.instance]
  end
  helper_method :available_producers

  def available_tags
    @available_tags ||=
      all_available_products(params.slice(:producer_id))
        .flat_map(&:tags)
        .uniq
        .sort_by(&:name)
  end
  helper_method :available_tags

  def all_available_products(pparams = params)
    products = delivery.available_shop_products(current_member.next_basket&.depot)
    products = products.preload(:variants, :tags, :producer, "rich_text_description_#{I18n.locale}".to_sym)
    if pparams[:producer_id].present?
      products = products.where(producer_id: pparams[:producer_id])
    end
    if pparams[:tag_id].present?
      products =
        products
          .joins(:shop_products_tags)
          .where(shop_products_tags: { tag_id: pparams[:tag_id] })
    end
    products
  end
end


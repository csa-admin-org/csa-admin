class BasketContent
  ActiveAdmin.register Product do
    menu false
    actions :all, except: [:show]

    breadcrumb do
      links = [link_to(BasketContent.model_name.human(count: 2), basket_contents_path)]
      if params[:action] != 'index'
        links << link_to(Product.model_name.human(count: 2), basket_content_products_path)
      end
      if params['action'].in? %W[edit]
        links << resource.name
      end
      links
    end

    includes :basket_contents, :latest_basket_content
    index do
      column :name
      column :url, ->(p) { link_to(p.url_domain, p.url) if p.url? }
      column(:latest_use) { |p|
        if p.latest_basket_content
          display_with_unit_price(p.latest_basket_content.unit_price, p.latest_basket_content.unit) {
            link_to(
              l(p.latest_basket_content.delivery.date),
              basket_contents_path(q: { delivery_id_eq: p.latest_basket_content.delivery_id }))
          }
        end
      }
      if authorized?(:update, Product)
        actions class: 'col-actions-2'
      end
    end

    csv do
      column(:id)
      column(:name)
      column(:url)
      column(:latest_delivery) { |p|
        p.latest_basket_content&.delivery&.date
      }
      column(:latest_unit) { |p|
        if p.latest_basket_content
          I18n.t("units.#{p.latest_basket_content.unit}")
        end
      }
      column(:latest_quantity) { |p| p.latest_basket_content&.quantity }
      column(:latest_unit_price) { |p| p.latest_basket_content&.unit_price }
    end

    show do
      attributes_table do
        row :name
        row :url
      end
    end

    form do |f|
      f.inputs do
        translated_input(f, :names)
        f.input :url, hint: t('formtastic.hints.basket_content/product.url')
      end
      f.actions
    end

    permit_params(:url, *I18n.available_locales.map { |l| "name_#{l}" })

    controller do
      include TranslatedCSVFilename
    end

    config.filters = false
    config.per_page = 50
    config.sort_order = :default_scope
  end
end

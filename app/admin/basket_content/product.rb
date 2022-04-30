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

    includes :basket_contents
    index do
      column :name
      column :url, ->(bc) { link_to(bc.url_domain, bc.url) if bc.url? }
      if authorized?(:update, Product)
        actions class: 'col-actions-2'
      end
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

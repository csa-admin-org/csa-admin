ActiveAdmin.register BasketComplement do
  menu parent: :other, priority: 9, label: -> { t('active_admin.menu.basket_complements') }
  actions :all, except: [:show]

  scope :all
  scope :visible, default: true
  scope :hidden

  includes :memberships_basket_complements, :current_deliveries, :future_deliveries
  index download_links: false do
    column :id
    column :name
    column :price_type, -> (bc) {
      BasketComplement.human_attribute_name("price_type/#{bc.price_type}")
    }
    column :price, ->(bc) {
      if bc.annual_price_type?
        cur(bc.annual_price)
      else
        cur(bc.delivery_price)
      end
    }
    column :annual_price, ->(bc) {
      if bc.deliveries_count.positive?
        cur(bc.annual_price)
      end
    }
    column deliveries_current_year_title, ->(bc) {
      link_to bc.current_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.acp.current_fiscal_year.year
        },
        scope: :all)
    }
    column deliveries_next_year_title, ->(bc) {
      link_to bc.future_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.acp.current_fiscal_year.year + 1
        },
        scope: :all)
    }
    column :visible
    if authorized?(:update, BasketComplement)
      actions class: 'col-actions-2'
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      translated_input(f, :public_names,
        hint: t('formtastic.hints.basket_complement.public_name'))
      f.input :price_type,
        as: :select,
        prompt: true,
        collection: BasketComplement::PRICE_TYPES.map { |type|
          [BasketComplement.human_attribute_name("price_type/#{type}"), type]
        }
      f.input :price, as: :number, min: 0, hint: f.object.persisted?
    end

    f.inputs t('active_admin.resource.show.member_new_form') do
      f.input :form_priority, hint: true
      f.input :visible, as: :select, include_blank: false
      translated_input(f, :form_details,
        hint: t('formtastic.hints.basket_complement.form_detail'),
        input_html: {
          placeholder: basket_complement_details(f.object, force_default: true)
        })
    end

    f.inputs do
      if Delivery.current_year.any?
        f.input :current_deliveries,
          label: deliveries_current_year_title,
          as: :check_boxes,
          collection: Delivery.current_year,
          hint: f.object.persisted? ? t('formtastic.hints.basket_complement.current_deliveries_html') : nil
      end
      if Delivery.future_year.any?
        f.input :future_deliveries,
          label: deliveries_next_year_title,
          as: :check_boxes,
          collection: Delivery.future_year,
          hint: f.object.persisted?
      end

      para class: 'actions' do
        a href: handbook_page_path('deliveries', anchor: 'complments-de-panier'), class: 'action' do
          span do
            span inline_svg_tag('admin/book-open.svg', size: '20', title: t('layouts.footer.handbook'))
            span t('.check_handbook')
          end
        end.html_safe
      end
    end

    f.actions
  end

  permit_params(
    :price,
    :price_type,
    :visible,
    :form_priority,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    current_delivery_ids: [],
    future_delivery_ids: [])

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = :default_scope
end

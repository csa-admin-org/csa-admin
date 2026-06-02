# frozen_string_literal: true

class BasketContent
  module Form
    extend ActiveSupport::Concern

    def apply_form_params!(request_params)
      return self unless request_params[:distribution_source].present?

      form_params = request_params[:basket_content]
      return self unless form_params

      apply_form_delivery(form_params)
      apply_form_product(form_params)
      apply_form_depots(request_params, form_params)
      if product_source?(request_params)
        apply_product_defaults
      elsif form_param?(form_params, :unit_price)
        self.unit_price = form_param(form_params, :unit_price)
      end
      self
    end

    def form_distribution_data(request_params)
      if request_params[:distribution_source].present?
        interactive_form_distribution_data(request_params)
      else
        persisted_form_distribution_data
      end
    end

    private

    def apply_form_delivery(form_params)
      return unless form_param?(form_params, :delivery_id)

      self.delivery = Delivery.find_by(id: form_param(form_params, :delivery_id))
    end

    def apply_form_product(form_params)
      return unless form_param?(form_params, :product_id)

      self.product = BasketContent::Product.find_by(id: form_param(form_params, :product_id))
      self.unit = product.unit if product
    end

    def apply_form_depots(request_params, form_params)
      selected_depots = Depot.where(id: form_depot_ids(request_params, form_params)).to_a
      association(:depots).target = selected_depots
      association(:depots).loaded!
    end

    def apply_product_defaults
      self.unit_price = product&.default_price
      self.basket_size_ids_quantities = product&.default_basket_quantities || {}
    end

    def form_param?(form_params, key)
      form_params.respond_to?(:key?) &&
        (form_params.key?(key) || form_params.key?(key.to_s))
    end

    def form_param(form_params, key)
      return form_params[key] if form_params.key?(key)

      form_params[key.to_s]
    end

    def interactive_form_distribution_data(request_params)
      form_params = request_params[:basket_content] || {}
      product = form_product(form_params)
      depot_ids = form_depot_ids(request_params, form_params)
      delivery = Delivery.find_by(id: form_param(form_params, :delivery_id)) || self.delivery
      distribution_params = {
        product_id: product&.id,
        unit: form_param(form_params, :unit),
        unit_price: form_unit_price(request_params, form_params, product),
        total_quantity: product_source?(request_params) ? nil : request_params[:total_quantity],
        basket_size_ids_quantities: form_quantities(request_params, form_params, product),
        basket_size_ids_percentages: request_params[:basket_size_ids_percentages],
        depot_ids: depot_ids,
        distribution_source: product_source?(request_params) ? "quantity" : request_params[:distribution_source],
        preset: request_params[:preset],
        id: persisted? ? id : request_params[:id]
      }

      distribution_for(delivery, distribution_params).merge(depot_ids: depot_ids)
    end

    def persisted_form_distribution_data
      depot_ids = self.depot_ids.presence || Depot.kept.pluck(:id)
      distribution_params = {
        product_id: product_id,
        unit: unit,
        unit_price: unit_price,
        total_quantity: total_quantity.positive? ? total_quantity : 0,
        basket_size_ids_quantities: basket_size_ids_quantities,
        basket_size_ids_percentages: basket_size_ids_percentages.presence || basket_size_ids_percentages_pro_rated,
        depot_ids: depot_ids,
        distribution_source: "quantity",
        id: persisted? ? id : nil
      }

      distribution_for(delivery, distribution_params).merge(depot_ids: depot_ids)
    end

    def distribution_for(delivery, distribution_params)
      Distribution.new(delivery: delivery, params: distribution_params).to_h
    end

    def form_depot_ids(request_params, form_params)
      if form_param?(form_params, :depot_ids)
        return Array(form_param(form_params, :depot_ids)).map(&:to_i).reject(&:zero?)
      end

      ids = Array(request_params[:depot_ids]).map(&:to_i).reject(&:zero?)
      ids.presence || (request_params[:depot_ids_empty] == "1" ? [] : Depot.kept.pluck(:id))
    end

    def form_product(form_params)
      BasketContent::Product.find_by(id: form_param(form_params, :product_id)) || product
    end

    def form_unit_price(request_params, form_params, product)
      product_source?(request_params) ? product&.default_price : form_param(form_params, :unit_price)
    end

    def form_quantities(request_params, form_params, product)
      product_source?(request_params) ? (product&.default_basket_quantities || {}) : form_param(form_params, :basket_size_ids_quantities)
    end

    def product_source?(request_params)
      request_params[:distribution_source].to_s.in?(%w[product product_id])
    end
  end
end

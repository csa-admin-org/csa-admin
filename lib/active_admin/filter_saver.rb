module ActiveAdmin
  # Extends the ActiveAdmin controller to persist and restore
  # index q/scope filter params between NON-GET requests.
  module FilterSaver
    extend ActiveSupport::Concern

    included do
      before_action :restore_filter_params, only: :index
      before_action :persist_filter_params, only: :index
      before_action :persist_request_method
    end

    private

    def restore_filter_params
      if from_non_get_request? && filter_params.empty?
        params.merge!(filter_params_store[controller_key])
      else
        filter_params_store.delete(controller_key)
      end
    end

    def persist_filter_params
      filter_params_store[controller_key] = filter_params
    end

    def persist_request_method
      session[:last_request_method] = request.env["REQUEST_METHOD"]
    end

    def from_non_get_request?
      session[:last_request_method] && session[:last_request_method] != "GET"
    end

    def filter_params
      params.slice(:q, :scope)
    end

    def filter_params_store
      session[:last_filter_params] ||= Hash.new
    end

    def controller_key
      params[:controller].underscore
    end
  end
end

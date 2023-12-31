module Shop
  class NullProducer
    include ActiveModel::Model
    include Singleton

    def id; "null" end

    def name
      I18n.t("shop.producers.null_producer")
    end

    def website_url?
      false
    end
  end
end

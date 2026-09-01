# frozen_string_literal: true

# Variant generation raises Vips::Error when a blob is labeled as an image
# but the bytes are not a format libvips can load (AppSignal #458).
# after_initialize: the gem controller is not loaded while initializers run.
Rails.application.config.after_initialize do
  ActiveStorage::Representations::BaseController.class_eval do
    private

    def set_representation
      @representation = @blob.representation(params[:variation_key]).processed
    rescue ActiveSupport::MessageVerifier::InvalidSignature, Vips::Error, ImageProcessing::Error
      head :not_found
    end
  end
end

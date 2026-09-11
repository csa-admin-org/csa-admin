# frozen_string_literal: true

module Query
  class BlobsController < BaseController
    include ActionController::DataStreaming

    rescue_from ActiveStorage::FileNotFoundError, with: :render_not_found

    def show
      blob = ActiveStorage::Blob.find(params[:id])
      send_data blob.download,
        filename: blob.filename.to_s,
        type: blob.content_type,
        disposition: "inline"
    end
  end
end

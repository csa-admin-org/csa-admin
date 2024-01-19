# Fix rails_blob_path not using the right schema when linking to a blob
# https://github.com/rails-on-services/apartment/issues/196
module Tenant
  module ActiveRecordSignedIdACP
    def find_signed!(signed_id, purpose: nil)
      if id = signed_id_verifier.verify(signed_id, purpose: combine_signed_id_purposes(purpose))
        # Ensure the connection schema_search_path is well set
        raise "Tenant outside!" if Tenant.outside?
        Tenant.connect(Tenant.current)
        find(id)
      end
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ActiveRecord::RecordNotFound
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::SignedId::ClassMethods.send :prepend, Tenant::ActiveRecordSignedIdACP
end

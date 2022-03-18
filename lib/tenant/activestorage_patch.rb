# Fix rails_blob_path not using the right schema when linking to a blob
module ActiveRecordSignedIDACP
  def find_signed!(signed_id, purpose: nil)
    if id = signed_id_verifier.verify(signed_id, purpose: combine_signed_id_purposes(purpose))
      ACP.perform(Current.acp.tenant_name) do
        find(id)
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::SignedId::ClassMethods.send :prepend, ActiveRecordSignedIDACP
end

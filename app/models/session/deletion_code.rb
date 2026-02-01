# frozen_string_literal: true

# Adds deletion-code helpers to Session for the member self-deletion flow.
# Keeps code generation centralized while leaving state changes explicit.
module Session::DeletionCode
  extend ActiveSupport::Concern

  def rotate_deletion_code!
    touch(:updated_at)
  end

  def deletion_code
    DeletionCode.generate(self)
  end
end

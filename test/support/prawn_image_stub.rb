# frozen_string_literal: true

# Skip image rendering, as it takes time and not necessary for testing.
module PrawnImageStub
  def image(*args); end
end

Prawn::Document.prepend(PrawnImageStub)

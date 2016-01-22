require 'rails_helper'

describe Gribouille do
  describe '#deliverable' do
    specify do
      expect(Gribouille.new(header: 'foo', basket_content: 'bar'))
        .to be_deliverable
    end
    specify do
      gribouille = Gribouille.new(
        header: 'foo',
        basket_content: 'bar',
        sent_at: Time.current
      )
      expect(gribouille).not_to be_deliverable
    end
    specify do
      expect(Gribouille.new(basket_content: 'bar')).not_to be_deliverable
    end
    specify { expect(Gribouille.new(header: 'foo')).not_to be_deliverable }
    specify { expect(Gribouille.new(footer: 'foo')).not_to be_deliverable }
  end
end

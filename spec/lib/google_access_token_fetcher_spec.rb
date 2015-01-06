require 'rails_helper'
require 'google_access_token_fetcher'

describe GoogleAccessTokenFetcher do
  describe '.access_token' do
    it 'returns an access_token' do
      expect(described_class.access_token).to be_present
    end
  end
end

require 'rails_helper'

describe Billing::Snapshot, freeze: '2020-03-31 23:59:55 +02' do
  describe '#create_or_update_current_quarter!' do
    it 'creates a new snapshot' do
      snapshot = nil
      expect {
        snapshot = described_class.create_or_update_current_quarter!
      }.to change { described_class.count }.by(1)

      expect(snapshot.file).to be_present
      expect(snapshot.file.filename)
        .to eq 'rage-de-vert-facturation-20200331-23h59.xlsx'
      expect(snapshot.file.content_type)
        .to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    it 'updates an existing quarter snapshot' do
      snapshot = described_class.create_or_update_current_quarter!

      travel_to '2020-03-31 23:59:59 +02'

      expect {
        snapshot = described_class.create_or_update_current_quarter!
      }.not_to change { described_class.count }

      expect(snapshot.file).to be_present
      expect(snapshot.file.filename)
        .to eq 'rage-de-vert-facturation-20200331-23h59.xlsx'
      expect(snapshot.file.content_type)
        .to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    it 'does not create a new snapshot when it is too late' do
      travel_to '2020-04-01 00:10:00 +02'

      expect {
        described_class.create_or_update_current_quarter!
      }.not_to change { described_class.count }
    end
  end
end

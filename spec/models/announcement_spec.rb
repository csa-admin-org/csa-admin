require 'rails_helper'

describe Announcement do
  specify '#must_be_unique_per_depot_and_delivery' do
    delivery = create(:delivery)
    depot = create(:depot)
    Announcement.create!(
      text: 'Ramenez les sacs!',
      depot_ids: [depot.id],
      delivery_ids: [delivery.id])

    annoucement = Announcement.new(
      text: 'La semaine prochaine pas de livraison',
      depot_ids: [depot.id],
      delivery_ids: [delivery.id])

    expect(annoucement).not_to have_valid(:base)
    expect(annoucement.errors[:base].first)
      .to starting_with("Il y'a déjà une annonce pour la livraison du ")
  end
end

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Admin.delete_all
Admin.create!(
  email: 'thibaud@thibaud.gg',
  password: '12345678',
  password_confirmation: '12345678'
)

Distribution.delete_all
Distribution.create!(name: 'Jardin de la main',
  address: 'Rue de la Main 6-8',
  city: 'Neuchâtel',
  zip: 2000,
  basket_price: 0
)
Distribution.create!(name: 'Vélo',
  address: '–',
  city: 'Neuchâtel',
  zip: 2000,
  basket_price: 7
)
Distribution.create!(name: 'Vin libre',
  address: 'Rue des Chavannes 15',
  city: 'Neuchâtel',
  zip: 2000,
  basket_price: 2
)
Distribution.create!(name: "L'Entre-deux",
  address: 'Rue Jaquet-Droz 27',
  city: 'La Chaux-de-Fonds',
  zip: 2300,
  basket_price: 2
)
Distribution.create!(name: 'Particulier',
  address: 'Route de la Falaise 3',
  city: 'Marin-Epagnier',
  zip: 2074,
  basket_price: 2
)
Distribution.create!(name: 'Ancienne laiterie',
  address: '???',
  city: 'La Chaux-du-Milieu',
  zip: 2405,
  basket_price: 2
)
Distribution.create!(name: 'Particulier',
  address: '???',
  city: 'Colombier',
  zip: 2013,
  basket_price: 2
)

Basket.delete_all
Basket.create!(name: 'Eveil',
  year: 2015,
  annual_price: 925,
  annual_halfday_works: 2
)
Basket.create!(name: 'Abondance',
  year: 2015,
  annual_price: 1330,
  annual_halfday_works: 2
)

Delivery.delete_all
Delivery.create_all(Date.new(2015, 1, 14))

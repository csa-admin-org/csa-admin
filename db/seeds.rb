# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

ACP.create!(
  name: 'Rage de Vert',
  host: 'ragedevert',
  tenant_name: 'ragedevert')

Admin.delete_all
Admin.create!(
  name: 'Thibaud',
  rights: 'superadmin',
  email: 'thibaud@thibaud.gg',
  password: '12345678',
  password_confirmation: '12345678')

Depot.delete_all
Depot.create!(name: 'Jardin de la main',
  address: 'Rue de la Main 6-8',
  city: 'Neuchâtel',
  zip: 2000,
  price: 0
)
Depot.create!(name: 'Vélo',
  address: '–',
  city: 'Neuchâtel',
  zip: 2000,
  price: 7
)
Depot.create!(name: 'Vin libre',
  address: 'Rue des Chavannes 15',
  city: 'Neuchâtel',
  zip: 2000,
  price: 2
)
Depot.create!(name: "L'Entre-deux",
  address: 'Rue Jaquet-Droz 27',
  city: 'La Chaux-de-Fonds',
  zip: 2300,
  price: 2
)
Depot.create!(name: 'Particulier',
  address: 'Route de la Falaise 3',
  city: 'Marin-Epagnier',
  zip: 2074,
  price: 2
)
Depot.create!(name: 'Ancienne laiterie',
  address: '???',
  city: 'La Chaux-du-Milieu',
  zip: 2405,
  price: 2
)
Depot.create!(name: 'Particulier',
  address: '???',
  city: 'Colombier',
  zip: 2013,
  price: 2
)

BasketSize.delete_all
BasketSize.create!(name: 'Eveil', size: 'small', annual_price: 925)
BasketSize.create!(name: 'Abondance', size: 'big', annual_price: 1330)

Delivery.delete_all
Delivery.create_all(40, Date.new(2015, 1, 14))

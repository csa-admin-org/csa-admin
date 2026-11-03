# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += %i[
  _key
  address
  api_key
  body
  carpooling
  certificate
  city
  contract_password
  credentials
  crypt
  cvc
  cvv
  description
  details
  email
  from
  html
  iban
  installation_token
  liquid_data
  member_cards_attributes
  name
  note
  otp
  passw
  phone
  private_key
  profession
  recipient
  ref
  salt
  secret
  sql
  ssn
  street
  subject
  to
  token
  umr
  zip
]

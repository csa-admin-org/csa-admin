# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: Tenant.all.map(&:to_sym).map { |tenant|
    [ tenant, { writing: tenant } ]
  }.to_h

  def can_update?; true end
  def can_destroy?; true end

  def self.ransackable_attributes(auth_object = nil)
    authorizable_ransackable_attributes
  end

  def self.ransackable_associations(auth_object = nil)
    authorizable_ransackable_associations
  end

  def self.pk_sequence
    connection.execute("SELECT seq FROM sqlite_sequence WHERE name = '#{table_name}'").first&.fetch("seq")
  end

  def self.reset_pk_sequence!(force: nil)
    transaction do
      if pk_sequence
        max = maximum(:id) || 0
        raise "force value cannot be lower than max id" if force && force < max

        new_seq = force || max
        connection.execute(
          "UPDATE sqlite_sequence SET seq = #{new_seq} WHERE name = '#{table_name}'")
      else
        new_seq = force || 0
        connection.execute(
          "INSERT INTO sqlite_sequence (name, seq) VALUES ('#{table_name}', #{new_seq})")
      end
    end
  end
end

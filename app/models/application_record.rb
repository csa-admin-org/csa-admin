# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: Tenant.shards.map { |shard|
    [ shard, { writing: shard } ]
  }.to_h

  def can_update?; true end
  def can_destroy?; true end

  def self.ransackable_attributes(auth_object = nil)
    authorizable_ransackable_attributes
  end

  def self.ransackable_associations(auth_object = nil)
    authorizable_ransackable_associations
  end

  def self.reset_pk_sequence!
    new_seq = maximum(:id) || 0
    ActiveRecord::Base.connection.execute(
      "UPDATE sqlite_sequence SET seq = #{new_seq} WHERE name = '#{table_name}'")
  end
end

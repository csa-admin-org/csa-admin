# frozen_string_literal: true

class Demo::PageVisit < ApplicationRecord
  self.table_name = "demo_page_visits"

  MEANINGLESS_PAGE_KEYS = %w[dashboard#index].freeze

  belongs_to :admin
  belongs_to :session

  validates :path, :controller_name, :action_name, :page_key, :status, presence: true

  scope :recent, -> { where(created_at: 30.days.ago..) }
  scope :meaningful, -> { where.not(page_key: MEANINGLESS_PAGE_KEYS) }
  scope :for_admin, ->(admin) { where(admin: admin) }
  scope :by_page_popularity, -> { group(:page_key).order(Arel.sql("COUNT(*) DESC")) }

  def self.page_key_for(controller_path, action_name)
    "#{controller_path}##{action_name}"
  end

  def self.meaningful_page_key?(page_key)
    page_key.present? && !MEANINGLESS_PAGE_KEYS.include?(page_key)
  end

  def meaningful?
    self.class.meaningful_page_key?(page_key)
  end
end

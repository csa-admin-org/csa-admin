# frozen_string_literal: true

class Unavailable
  include ActiveModel::Model
  include Singleton

  def name
    model_name.human
  end
end

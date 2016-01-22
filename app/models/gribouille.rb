class Gribouille < ActiveRecord::Base
  belongs_to :member

  def deliverable?
    [header, basket_content].all?(&:present?) && !sent_at?
  end
end

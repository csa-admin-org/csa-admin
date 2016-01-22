class Gribouille < ActiveRecord::Base
  belongs_to :delivery

  def deliverable?
    [header, basket_content].all?(&:present?) && !sent_at?
  end
end

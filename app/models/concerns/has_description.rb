module HasDescription
  extend ActiveSupport::Concern

  private

  def describe(object, quantity, public_name: false)
    name = public_name ? object.public_name : object.name
    case quantity
    when 0 then nil
    when 1 then name
    else "#{quantity}x #{name}"
    end
  end
end

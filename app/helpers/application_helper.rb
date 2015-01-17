module ApplicationHelper
  def spaced(string, size: 4)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end
end

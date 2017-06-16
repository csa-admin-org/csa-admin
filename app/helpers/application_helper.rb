module ApplicationHelper
  def spaced(string, size: 3)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end

  def gribouille_content(html)
    html.sub(/(<br>)+(<\/\w*>)*\z/) { |match| p match.gsub(/<br>/, '') }
  end
end

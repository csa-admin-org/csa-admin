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

  def display_emails(emails)
    Array(emails).map { |email| mail_to(email) }.join(', ').html_safe
  end

  def display_phones(phones)
    Array(phones).map { |phone|
      link_to(
        phone.phony_formatted,
        "tel:" + phone.phony_formatted(spaces: '', format: :international))
    }.join(', ').html_safe
  end
end

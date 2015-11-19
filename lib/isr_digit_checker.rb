module ISRDigitChecker
  SERIES = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5].freeze

  def check_digit!(string)
    "#{string}#{check_digit(string)}"
  end

  def check_digit(string)
    string = string.gsub(/\D/, '')
    carry = 0
    string.split(//).each { |char| carry = SERIES[(carry + char.to_i) % 10] }
    (10 - carry) % 10
  end
end

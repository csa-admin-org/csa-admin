require 'isr_digit_checker'

describe ISRDigitChecker do
  include ISRDigitChecker

  describe '.check_digit' do
    specify { expect(check_digit('00 11041 90802 41000 00000 0001')).to eq 6 }
    specify { expect(check_digit('00 11041 90802 41000 00000 0703')).to eq 0 }
    specify { expect(check_digit('00 11041 90802 41000 00000 0704')).to eq 1 }
    specify { expect(check_digit('00 11041 90802 41000 00000 0705')).to eq 6 }
    specify { expect(check_digit('00 11041 90802 41000 00000 0706')).to eq 4 }
    specify { expect(check_digit('00 11041 90802 41000 00000 0707')).to eq 2 }
    specify { expect(check_digit('12 00000 00000 23447 89432 1689')).to eq 9 }
    specify { expect(check_digit('96 11169 00000 00660 00000 0928')).to eq 4 }
    specify { expect(check_digit('210000044000')).to eq 1 }
    specify { expect(check_digit('01000162')).to eq 8 }
    specify { expect(check_digit('03000162')).to eq 5 }
  end

  describe '.check_digit!' do
    specify { expect(check_digit!('210000044000')).to eq '2100000440001' }
    specify { expect(check_digit!('0300 0162')).to eq '0300 01625' }
  end
end

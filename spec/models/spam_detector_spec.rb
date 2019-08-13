require 'rails_helper'

describe SpamDetector do
  def spam?(member)
    SpamDetector.spam?(member)
  end

  it 'detects too long note' do
    member = Member.new(note: 'fobar' * 1000 + 'A')
    expect(spam?(member)).to eq true
  end

  it 'detects too long food note' do
    member = Member.new(food_note: 'fobar' * 1000 + 'A')
    expect(spam?(member)).to eq true
  end

  it 'detects wrong zip' do
    member = Member.new(zip: '153535')
    expect(spam?(member)).to eq true
  end

  it 'detects cyrillic address' do
    member = Member.new(address: 'РњРѕСЃРєРІР°')
    expect(spam?(member)).to eq true
  end

  it 'detects cyrillic city' do
    member = Member.new(city: 'РњРѕСЃРєРІР°')
    expect(spam?(member)).to eq true
  end

  it 'detects cyrillic come_from' do
    member = Member.new(come_from: 'Р РѕСЃСЃРёСЏ')
    expect(spam?(member)).to eq true
  end

  it 'detects non native language text' do
    member = Member.new(note: 'Are you searching for a cloud accounting interface that makes operating your company easy, fast and safe?')
    expect(spam?(member)).to eq true
  end

  it 'ignores blank text' do
    member = Member.new(food_note: '')
    expect(spam?(member)).to eq false
  end

  it 'ignores short text' do
    member = Member.new(food_note: 'YEAH ROCK ON!')
    expect(spam?(member)).to eq false
  end

  it 'accepts native language text' do
    member = Member.new(note: 'Je me réjouis vraiment de recevoir mon panier!')
    expect(spam?(member)).to eq false
  end
end

require 'rails_helper'

describe 'Shop' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  specify 'no shop delivery' do
    visit '/shop'
    expect(current_path).not_to eq '/shop'
  end

  context 'with shop delivery' do
    before do
      create(:delivery, shop_open: true, date: 1.week.from_now)
      create(:membership, member: member)
    end

    specify 'no shop feature' do
      Current.acp.update!(features: [])

      visit '/shop'
      expect(current_path).not_to eq '/shop'
    end

    specify 'menu only for session originated from admin' do
      Current.acp.update!(shop_admin_only: true, features: ['shop'])

      visit '/'
      expect(page).not_to have_css('nav li[aria-label="Shop Menu"]')

      member.sessions.last.update!(admin: create(:admin))

      visit '/'
      expect(page).to have_css('nav li[aria-label="Shop Menu"]')
    end

    specify 'open to members', freeze: '2022-01-01' do
      Current.acp.update!(shop_admin_only: false, features: ['shop'])

      visit '/'

      expect(page).to have_css('nav li[aria-label="Shop Menu"]')
    end
  end
end

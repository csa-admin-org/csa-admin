require 'rails_helper'

describe Auditable do
  it 'saves changes on audited attributes without session' do
    member = create(:member, name: 'Joe Doe')

    expect {
      member.update!(name: 'John Doe')
    }.to change(Audit, :count).by(1)

    expect(member.audits.last).to have_attributes(
      actor: System.instance,
      session: nil,
      audited_changes: {
        'name' => ['Joe Doe', 'John Doe']
      })
  end

  it 'saves changes on audited attributes with current session' do
    member = create(:member, name: 'Joe Doe')
    session = create(:session, member: member)
    Current.session = session

    expect {
      member.update!(name: 'John Doe', note: 'Doo')
    }.to change(Audit, :count).by(1)

    expect(member.audits.last).to have_attributes(
      actor: member,
      session: session,
      audited_changes: {
        'name' => ['Joe Doe', 'John Doe']
      })
  end
end

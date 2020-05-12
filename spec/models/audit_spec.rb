require 'rails_helper'

describe Auditable do
  it 'does nothing when audit_session is nil' do
    member = create(:member)

    expect {
      member.update!(name: 'John Doe')
    }.not_to change(Audit, :count)
  end

  it 'saves changes on audited attributes' do
    member = create(:member, name: 'Joe Doe')
    session = create(:session, member: member)
    member.audit_session = session

    expect {
      member.update!(name: 'John Doe', note: 'Doo')
    }.to change(Audit, :count).by(1)

    expect(member.audits.first).to have_attributes(
      session: session,
      audited_changes: {
        'name' => ['Joe Doe', 'John Doe']
      })
  end
end

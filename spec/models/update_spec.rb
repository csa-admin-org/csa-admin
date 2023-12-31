require "rails_helper"

describe Update do
  specify ".unread_count" do
    updates = Update.all

    admin = build(:admin, latest_update_read: nil)
    expect(Update.unread_count(admin)).to eq updates.size

    admin = build(:admin, latest_update_read: updates.first(2).last.name)
    expect(Update.unread_count(admin)).to eq 1
  end

  specify ".mark_as_read!" do
    updates = Update.all
    admin = create(:admin)
    admin.update!(latest_update_read: nil)

    expect { Update.mark_as_read!(admin) }
      .to change { admin.reload.latest_update_read }
      .from(nil)
      .to(updates.first.name)
  end
end

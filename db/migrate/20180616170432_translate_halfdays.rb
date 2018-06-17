class TranslateHalfdays < ActiveRecord::Migration[5.2]
  def change
    add_column :halfday_presets, :places, :jsonb, default: {}, null: false
    add_column :halfday_presets, :place_urls, :jsonb, default: {}, null: false
    add_column :halfday_presets, :activities, :jsonb, default: {}, null: false

    add_column :halfdays, :places, :jsonb, default: {}, null: false
    add_column :halfdays, :place_urls, :jsonb, default: {}, null: false
    add_column :halfdays, :activities, :jsonb, default: {}, null: false
    add_column :halfdays, :descriptions, :jsonb, default: {}, null: false

    acp = ACP.find_by(tenant_name: Apartment::Tenant.current)
    HalfdayPreset.find_each do |halfday_preset|
      places = acp.languages.map { |l| [l, halfday_preset[:place]] }.to_h
      place_urls = acp.languages.map { |l| [l, halfday_preset[:place_url]] }.to_h
      activities = acp.languages.map { |l| [l, halfday_preset[:activity]] }.to_h
      halfday_preset.update!(
        places: places,
        place_urls: place_urls,
        activities: activities)
    end
    Halfday.find_each do |halfday|
      places = acp.languages.map { |l| [l, halfday[:place]] }.to_h
      place_urls = acp.languages.map { |l| [l, halfday[:place_url]] }.to_h
      activities = acp.languages.map { |l| [l, halfday[:activity]] }.to_h
      descriptions = acp.languages.map { |l| [l, halfday[:description]] }.to_h
      halfday.update!(
        places: places,
        place_urls: place_urls,
        activities: activities,
        descriptions: descriptions)
    end

    add_index :halfday_presets, [:places, :activities], unique: true

    remove_column :halfday_presets, :place
    remove_column :halfday_presets, :place_url
    remove_column :halfday_presets, :activity
    remove_column :halfdays, :place
    remove_column :halfdays, :place_url
    remove_column :halfdays, :activity
    remove_column :halfdays, :description
  end
end

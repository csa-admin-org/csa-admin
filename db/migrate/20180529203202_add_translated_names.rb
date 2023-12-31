class AddTranslatedNames < ActiveRecord::Migration[5.2]
  def change
    add_column :basket_sizes, :names, :jsonb, default: {}, null: false
    add_column :basket_complements, :names, :jsonb, default: {}, null: false
    add_column :vegetables, :names, :jsonb, default: {}, null: false

    acp = Current.acp
    BasketSize.find_each do |basket_size|
      names = acp.languages.map { |l| [ l, basket_size[:name] ] }.to_h
      basket_size.update!(names: names)
    end
    BasketComplement.find_each do |basket_complement|
      names = acp.languages.map { |l| [ l, basket_complement[:name] ] }.to_h
      basket_complement.update!(names: names)
    end
    Vegetable.find_each do |vegetable|
      names = acp.languages.map { |l| [ l, vegetable[:name] ] }.to_h
      vegetable.update!(names: names)
    end

    remove_column :basket_sizes, :name
    remove_column :basket_complements, :name
    remove_column :vegetables, :name
  end
end

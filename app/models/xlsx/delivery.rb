module XLSX
  class Delivery < Base
    include ActionView::Helpers::TextHelper

    def initialize(delivery, distribution = nil)
      @delivery = delivery
      @distribution = distribution
      @baskets = @delivery.baskets.not_absent
      @distributions = Distribution.where id: @baskets.pluck(:distribution_id).uniq
      @basket_complements = BasketComplement.all
      @basket_sizes = BasketSize.all

      build_recap_worksheet('Récapitulatif') unless @distribution

      Array(@distribution || @distributions).each do |dist|
        build_distribution_worksheet(dist)
      end
    end

    def filename
      [
        'livraison',
        "##{@delivery.number}",
        @delivery.date.strftime('%Y%m%d')
      ].join('-') + '.xlsx'
    end

    private

    def build_recap_worksheet(name)
      add_worksheet(name)

      cols = ['', 'Total']
      cols += @basket_sizes.map(&:name)
      if @basket_complements.any?
        cols << ''
        cols += @basket_complements.map(&:name)
      end
      add_header(*cols)

      @distributions.each do |distribution|
        add_baskets_line(distribution.name, @baskets.where(distribution_id: distribution.id))
      end
      add_empty_line

      if free_distributions = @distributions.free
        free_name = free_distributions.pluck(:name).to_sentence
        free_ids = free_distributions.pluck(:id)
        add_baskets_line("Paniers: #{free_name}", @baskets.where(distribution_id: free_ids))
        paid_ids = @distributions.paid.pluck(:id)
        add_baskets_line("Paniers à préparer", @baskets.where(distribution_id: paid_ids))
        add_empty_line
      end

      add_baskets_line('Total', @baskets, bold: true)

      add_empty_line
      add_empty_line

      @worksheet.add_cell(@line, 0, 'Absences')
      @worksheet.add_cell(@line, 1, @delivery.baskets.absent.count).set_number_format('0')

      @worksheet.change_column_width(0, 35)
      (1..(2 + @basket_sizes.count + @basket_complements.count)).each do |i|
        @worksheet.change_column_width(i, 15)
        @worksheet.change_column_horizontal_alignment(i, 'right')
      end
    end

    def add_baskets_line(description, baskets, bold: false)
      @worksheet.add_cell(@line, 0, description)
      @worksheet.add_cell(@line, 1, baskets.count).set_number_format('0')
      @basket_sizes.each_with_index do |basket_size, i|
        amount = baskets.where(basket_size_id: basket_size.id).sum(:quantity)
        @worksheet.add_cell(@line, 2 + i, amount).set_number_format('0')
      end
      if @basket_complements.any?
        cols_count = 3 + @basket_sizes.count
        @basket_complements.each_with_index do |complement, i|
          amount =
            baskets
              .joins(:baskets_basket_complements)
              .where(baskets_basket_complements: { basket_complement_id: complement.id })
              .sum('baskets_basket_complements.quantity')
          @worksheet.add_cell(@line, cols_count + i, amount).set_number_format('0')
        end
      end
      @worksheet.change_row_bold(@line, bold)

      @line += 1
    end

    def build_distribution_worksheet(distribution)
      baskets = @baskets.where(distribution_id: distribution.id)
      basket_counts = @basket_sizes.map { |bs| baskets.where(basket_size_id: bs.id).sum(:quantity) }
      add_worksheet("#{distribution.name} (#{basket_counts.join('+')})")

      cols = %w[
        Nom
        Emails
        Téléphones
        Adresse
        Zip
        Ville
        Panier
      ]
      cols << 'Compléments' if @basket_complements.any?
      cols << 'Note alimentaire'
      add_header(*cols)
      baskets
        .joins(:member)
        .includes(:member, :basket_size, :baskets_basket_complements, :complements).order('members.name')
        .not_empty
        .each { |basket| add_basket_line(basket) }

      @worksheet.change_column_width(0, 35)
      @worksheet.change_column_width(1, 30)
      @worksheet.change_column_width(2, 15)
      @worksheet.change_column_width(3, 30)
      @worksheet.change_column_width(4, 6)
      @worksheet.change_column_width(5, 20)
      @worksheet.change_column_width(6, 10)
      @worksheet.change_column_width(7, 30)
      @worksheet.change_column_width(8, 50)
    end

    def add_basket_line(basket)
      member = basket.member
      cols = [
        member.name,
        member.emails_array.join(', '),
        member.phones_array.map(&:phony_formatted).join(', '),
        member.final_delivery_address,
        member.final_delivery_zip,
        member.final_delivery_city,
        basket.basket_description || '-'
      ]
      cols << basket.complements_description if @basket_complements.any?
      cols << truncate(member.food_note, length: 80)
      cols.each_with_index do |col, i|
        @worksheet.add_cell(@line, i, col)
      end
      @line += 1
    end
  end
end

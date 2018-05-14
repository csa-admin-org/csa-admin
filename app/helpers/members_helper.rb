module MembersHelper
  def languages_collection
    Current.acp.languages.map { |l| [t("languages.#{l}"), l] }
  end

  def billing_year_divisions_collection
    Current.acp.billing_year_divisions.map { |i|
      ["<span>#{I18n.t("billing.year_division.x#{i}")}</span>".html_safe, i]
    }
  end

  def basket_sizes_collection
    BasketSize.all.map { |bs|
      [
        collection_text(bs.name, bs.annual_price, [
          deliveries_count(bs.deliveries_count),
          halfdays_count(bs.annual_halfday_works)
        ].join(', ')),
        bs.id
      ]
    }
  end

  def basket_complements_collection
    BasketComplement.includes(:deliveries).map { |bc|
      [
        collection_text(bc.name,
          bc.annual_price,
          deliveries_count(bc.deliveries.size),
          precision: 2),
        bc.id
      ]
    }
  end

  def distributions_collection
    Distribution.visible.reorder('price, name').map { |d|
      location = [d.address, "#{d.zip} #{d.city}".presence].compact.join(', ') if d.address?
      txt = collection_text(d.name, d.annual_price, location)
      if location && location != d.address
        txt += map_icon(location).html_safe
      end

      [txt, d.id]
    }
  end

  private

  def collection_text(text, price, details, precision: 0)
    txts = [text]
    txts << "<em class='price'>#{number_to_currency(price, precision: precision)}</em>" if price.positive?
    txts << "<em>(#{details})</em>" if details.present?
    "<span>#{txts.join}</span>".html_safe
  end

  def map_icon(location)
    <<-TXT
      <a href="https://www.google.com/maps?q=#{location}" title="#{location}" target="_blank">
        <i class="fa fa-map-signs"></i>
      </a>
    TXT
  end

  def deliveries_count(count)
    "#{count}&nbsp;#{Delivery.model_name.human(count: count)}".downcase
  end

  def halfdays_count(count)
    t_halfday('helpers.halfdays_count_per_year', count: count).gsub(/\s/, '&nbsp;')
  end
end

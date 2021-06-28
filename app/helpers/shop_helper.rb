module ShopHelper
  def display_variants(arbre, product)
    arbre.ul do
      product.variants.each do |variant|
        arbre.li do
          arbre.span do
            parts = [variant.name]
            parts << cur(variant.price)
            parts << "<b>#{variant.stock}x</b>" unless variant.stock.nil?
            parts.join(', ').html_safe
          end
        end
      end
    end
  end
end

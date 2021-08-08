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

  def product_variants_collection(products)
    products.includes(:variants).flat_map do |product|
      product.variants.map do |variant|
        [variant.name, variant.id, data: { product_id: variant.product_id }]
      end
    end
  end
end

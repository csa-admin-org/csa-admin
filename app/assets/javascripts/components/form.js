const resetPrice = (el) => {
  var nextInput = $(el)
    .closest("li.select")
    .nextAll(".number")
    .first()
    .find('input[type="number"]');
  nextInput.prop("value", "");
};

const updateProductVariantOptions = (el) => {
  var selectedProductID = el.value;
  const selectID = el.id.replace("_id", "_variant_id");
  const variantsSelect = document.getElementById(selectID);

  variantsSelect.removeAttribute("disabled");
  Array.from(variantsSelect.options).forEach((option) => {
    if (selectedProductID === option.getAttribute("data-product-id")) {
      option.disabled = option.getAttribute("data-disabled") == "true";
      option.hidden = option.getAttribute("data-disabled") == "true";
      option.selected = option.getAttribute("data-disabled") == "true";
    } else {
      option.disabled = true;
      option.hidden = true;
      option.selected = false;
    }
  });
  Array.from(variantsSelect.options).find((o) => !o.disabled).selected = true;
};

$(document).on("turbolinks:load", function() {
  $(".js-reset_price").on("change", function() {
    resetPrice(this);
  });
  $(".js-update_product_variant_options").on("change", function() {
    updateProductVariantOptions(this);
  });

  $(document).on("has_many_add:after", ".has_many_container", function(
    e,
    fieldset,
    container
  ) {
    $(".js-reset_price").on("change", function() {
      resetPrice(this);
    });
    $(".js-update_product_variant_options").on("change", function() {
      updateProductVariantOptions(this);
    });
  });

  $(".js-update_basket_depot_options").on("change", function() {
    var selectedDeliveryID = this.value;
    var depotSelect = document.querySelector("#basket_depot_id");
    var selectedDepotID = depotSelect.value;
    Array.from(depotSelect.options).forEach(option => {
      var deliveryIds = option.getAttribute("data-delivery-ids").split(",");
      if (deliveryIds.some((id) => id === selectedDeliveryID)) {
        option.disabled = false;
        option.selected = false;
      } else {
        option.disabled = true;
        option.selected = false;
      }
      if (option.value === selectedDepotID && !option.disabled) {
        option.selected = true;
      }
    });
  });
});

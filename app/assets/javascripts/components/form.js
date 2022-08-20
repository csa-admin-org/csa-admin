$(document).on("turbolinks:load", function() {
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

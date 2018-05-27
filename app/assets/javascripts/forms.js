$(function() {
  $('#member_waiting_basket_size_input input:radio').on('change', function() {
    console.log(this.value);
    if (this.value === '0') {
      $('#member_waiting_basket_complement_ids_input input:checkbox').prop(
        'checked',
        false
      );
      $('#member_waiting_basket_complement_ids_input').addClass('disabled');
      $('#member_waiting_basket_complement_ids_input input:checkbox').prop(
        'disabled',
        true
      );

      $('#member_waiting_distribution_input input:radio').prop(
        'checked',
        false
      );
      $('#member_waiting_distribution_input').addClass('disabled');
      $('#member_waiting_distribution_input input:radio').prop(
        'disabled',
        true
      );

      $('#member_billing_year_division_input').addClass('disabled');
      $('#member_billing_year_division_input input:radio').prop(
        'checked',
        false
      );
      $('#member_billing_year_division_input input:radio').prop(
        'disabled',
        true
      );
      $('label[for=member_billing_year_division_1]').removeClass('disabled');
      $('#member_billing_year_division_1').prop('checked', true);
      $('#member_billing_year_division_1').prop('disabled', false);
    } else {
      $('#member_waiting_basket_complement_ids_input').removeClass('disabled');
      $('#member_waiting_basket_complement_ids_input input:checkbox').prop(
        'disabled',
        false
      );

      $('#member_waiting_distribution_input').removeClass('disabled');
      $('#member_waiting_distribution_input input:radio').prop(
        'disabled',
        false
      );

      $('#member_billing_year_division_input').removeClass('disabled');
      $('#member_billing_year_division_input input:radio').prop(
        'disabled',
        false
      );
    }
  });
});

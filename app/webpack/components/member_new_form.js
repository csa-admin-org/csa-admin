import { live, checked, removeValues, resetValues, prop, addClass, removeClass } from 'components/utils';

document.addEventListener('turbolinks:load', () => {
  live("#member_waiting_basket_size_input input[type='radio']", 'change', event => {
    const extraPrice = '#member_waiting_basket_price_extra_input';
    const extraPriceRadios = `${extraPrice} input[type='radio']`;
    const complements = 'fieldset.members_basket_complements';
    const complementsInputs = `${complements} input[type='number']`;
    const depots = '#member_waiting_depot_input';
    const depotsRadios = `${depots} input[type='radio']`;
    const billingYearDivision = '#member_billing_year_division_input';
    const billingYearDivisionRadios = `${billingYearDivision} input[type='radio']`;
    const billingYearDivision1 = '#member_billing_year_division_1';
    const billingYearDivision1Label = 'label[for=member_billing_year_division_1]';

    if (event.target.value === '0') {
      addClass(extraPrice, 'disabled');
      checked(extraPriceRadios, false);
      prop(extraPriceRadios, 'disabled', true);

      addClass(complements, 'disabled');
      removeValues(complementsInputs);
      prop(complementsInputs, 'disabled', true);

      addClass(depots, 'disabled');
      checked(depotsRadios, false);
      prop(depotsRadios, 'disabled', true);

      addClass(billingYearDivision, 'disabled');
      checked(billingYearDivisionRadios, false);
      prop(billingYearDivisionRadios, 'disabled', true);

      removeClass(billingYearDivision1Label, 'disabled');
      checked(billingYearDivision1, true);
      prop(billingYearDivision1, 'disabled', false);
    } else {
      removeClass(extraPrice, 'disabled');
      prop(extraPriceRadios, 'disabled', false);

      removeClass(complements, 'disabled');
      resetValues(complementsInputs, 0);
      prop(complementsInputs, 'disabled', false);

      removeClass(depots, 'disabled');
      prop(depotsRadios, 'disabled', false);

      removeClass(billingYearDivision, 'disabled');
      prop(billingYearDivisionRadios, 'disabled', false);
    }
  });
});

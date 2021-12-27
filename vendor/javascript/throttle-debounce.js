/**
 * Throttle execution of a function. Especially useful for rate limiting
 * execution of handlers on events like resize and scroll.
 *
 * @param  {number}    delay -          A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher) are most useful.
 * @param  {boolean}   [noTrailing] -   Optional, defaults to false. If noTrailing is true, callback will only execute every `delay` milliseconds while the
 *                                    throttled-function is being called. If noTrailing is false or unspecified, callback will be executed one final time
 *                                    after the last throttled-function call. (After the throttled-function has not been called for `delay` milliseconds,
 *                                    the internal counter is reset).
 * @param  {Function}  callback -       A function to be executed after delay milliseconds. The `this` context and all arguments are passed through, as-is,
 *                                    to `callback` when the throttled-function is executed.
 * @param  {boolean}   [debounceMode] - If `debounceMode` is true (at begin), schedule `clear` to execute after `delay` ms. If `debounceMode` is false (at end),
 *                                    schedule `callback` to execute after `delay` ms.
 *
 * @returns {Function}  A new, throttled, function.
 */
 function throttle(e,t,r,o){var n;var a=false;var i=0;function clearExistingTimeout(){n&&clearTimeout(n)}function cancel(){clearExistingTimeout();a=true}if("boolean"!==typeof t){o=r;r=t;t=void 0}function wrapper(){for(var c=arguments.length,l=new Array(c),u=0;u<c;u++)l[u]=arguments[u];var f=this;var v=Date.now()-i;if(!a){o&&!n&&exec();clearExistingTimeout();void 0===o&&v>e?exec():true!==t&&(n=setTimeout(o?clear:exec,void 0===o?e-v:e))}function exec(){i=Date.now();r.apply(f,l)}function clear(){n=void 0}}wrapper.cancel=cancel;return wrapper}
 /**
  * Debounce execution of a function. Debouncing, unlike throttling,
  * guarantees that a function is only executed a single time, either at the
  * very beginning of a series of calls, or at the very end.
  *
  * @param  {number}   delay -         A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher) are most useful.
  * @param  {boolean}  [atBegin] -     Optional, defaults to false. If atBegin is false or unspecified, callback will only be executed `delay` milliseconds
  *                                  after the last debounced-function call. If atBegin is true, callback will be executed only at the first debounced-function call.
  *                                  (After the throttled-function has not been called for `delay` milliseconds, the internal counter is reset).
  * @param  {Function} callback -      A function to be executed after delay milliseconds. The `this` context and all arguments are passed through, as-is,
  *                                  to `callback` when the debounced-function is executed.
  *
  * @returns {Function} A new, debounced function.
  */function debounce(e,t,r){return void 0===r?throttle(e,t,false):throttle(e,r,false!==t)}export{debounce,throttle};

 //# sourceMappingURL=index.js.map

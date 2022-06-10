/**
 * Throttle execution of a function. Especially useful for rate limiting
 * execution of handlers on events like resize and scroll.
 *
 * @param {number} delay -                  A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher)
 *                                            are most useful.
 * @param {Function} callback -               A function to be executed after delay milliseconds. The `this` context and all arguments are passed through,
 *                                            as-is, to `callback` when the throttled-function is executed.
 * @param {object} [options] -              An object to configure options.
 * @param {boolean} [options.noTrailing] -   Optional, defaults to false. If noTrailing is true, callback will only execute every `delay` milliseconds
 *                                            while the throttled-function is being called. If noTrailing is false or unspecified, callback will be executed
 *                                            one final time after the last throttled-function call. (After the throttled-function has not been called for
 *                                            `delay` milliseconds, the internal counter is reset).
 * @param {boolean} [options.noLeading] -   Optional, defaults to false. If noLeading is false, the first throttled-function call will execute callback
 *                                            immediately. If noLeading is true, the first the callback execution will be skipped. It should be noted that
 *                                            callback will never executed if both noLeading = true and noTrailing = true.
 * @param {boolean} [options.debounceMode] - If `debounceMode` is true (at begin), schedule `clear` to execute after `delay` ms. If `debounceMode` is
 *                                            false (at end), schedule `callback` to execute after `delay` ms.
 *
 * @returns {Function} A new, throttled, function.
 */
function throttle(e,o,n){var i=n||{},t=i.noTrailing,r=void 0!==t&&t,a=i.noLeading,c=void 0!==a&&a,l=i.debounceMode,u=void 0===l?void 0:l;var v;var d=false;var f=0;function clearExistingTimeout(){v&&clearTimeout(v)}function cancel(e){var o=e||{},n=o.upcomingOnly,i=void 0!==n&&n;clearExistingTimeout();d=!i}function wrapper(){for(var n=arguments.length,i=new Array(n),t=0;t<n;t++)i[t]=arguments[t];var a=this;var l=Date.now()-f;if(!d){c||!u||v||exec();clearExistingTimeout();if(void 0===u&&l>e)if(c){f=Date.now();r||(v=setTimeout(u?clear:exec,e))}else exec();else true!==r&&(v=setTimeout(u?clear:exec,void 0===u?e-l:e))}function exec(){f=Date.now();o.apply(a,i)}function clear(){v=void 0}}wrapper.cancel=cancel;return wrapper}
/**
 * Debounce execution of a function. Debouncing, unlike throttling,
 * guarantees that a function is only executed a single time, either at the
 * very beginning of a series of calls, or at the very end.
 *
 * @param {number} delay -               A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher) are most useful.
 * @param {Function} callback -          A function to be executed after delay milliseconds. The `this` context and all arguments are passed through, as-is,
 *                                        to `callback` when the debounced-function is executed.
 * @param {object} [options] -           An object to configure options.
 * @param {boolean} [options.atBegin] -  Optional, defaults to false. If atBegin is false or unspecified, callback will only be executed `delay` milliseconds
 *                                        after the last debounced-function call. If atBegin is true, callback will be executed only at the first debounced-function call.
 *                                        (After the throttled-function has not been called for `delay` milliseconds, the internal counter is reset).
 *
 * @returns {Function} A new, debounced function.
 */function debounce(e,o,n){var i=n||{},t=i.atBegin,r=void 0!==t&&t;return throttle(e,o,{debounceMode:false!==r})}export{debounce,throttle};


import{addGlobalEventProcessor as e,getCurrentHub as t,updateSession as n,Scope as r}from"@sentry/hub";export{Hub,Scope,addBreadcrumb,addGlobalEventProcessor,captureEvent,captureException,captureMessage,configureScope,getCurrentHub,getHubFromCarrier,makeMain,setContext,setExtra,setExtras,setTag,setTags,setUser,startTransaction,withScope}from"@sentry/hub";import{urlEncode as s,makeDsn as i,dsnToString as o,createEnvelope as a,dropUndefinedKeys as d,getSentryBaggageItems as _,logger as p,checkOrSetAlreadyCaught as u,isPrimitive as l,resolvedSyncPromise as c,addItemToEnvelope as v,createAttachmentEnvelopeItem as h,SyncPromise as f,uuid4 as g,dateTimestampInSeconds as E,normalize as m,truncate as S,rejectedSyncPromise as y,SentryError as b,isThenable as D,isPlainObject as x,makePromiseBuffer as B,forEachEnvelopeItem as k,envelopeItemTypeToDataCategory as T,isRateLimited as w,serializeEnvelope as R,updateRateLimits as U}from"@sentry/utils";export{initAndBind}from"./sdk.js";import{FunctionToString as I}from"./integrations/functiontostring.js";export{FunctionToString}from"./integrations/functiontostring.js";import{InboundFilters as N}from"./integrations/inboundfilters.js";export{InboundFilters}from"./integrations/inboundfilters.js";var $="7";function getBaseApiEndpoint(e){var t=e.protocol?`${e.protocol}:`:"";var n=e.port?`:${e.port}`:"";return`${t}//${e.host}${n}${e.path?`/${e.path}`:""}/api/`}function _getIngestEndpoint(e){return`${getBaseApiEndpoint(e)}${e.projectId}/envelope/`}function _encodedAuth(e,t){return s({sentry_key:e.publicKey,sentry_version:$,...t&&{sentry_client:`${t.name}/${t.version}`}})}function getEnvelopeEndpointWithUrlEncodedAuth(e,t={}){var n="string"===typeof t?t:t.tunnel;var r="string"!==typeof t&&t._metadata?t._metadata.sdk:void 0;return n||`${_getIngestEndpoint(e)}?${_encodedAuth(e,r)}`}function getReportDialogEndpoint(e,t){var n=i(e);var r=`${getBaseApiEndpoint(n)}embed/error-page/`;let s=`dsn=${o(n)}`;for(var a in t)if("dsn"!==a)if("user"===a){var d=t.user;if(!d)continue;d.name&&(s+=`&name=${encodeURIComponent(d.name)}`);d.email&&(s+=`&email=${encodeURIComponent(d.email)}`)}else s+=`&${encodeURIComponent(a)}=${encodeURIComponent(t[a])}`;return`${r}?${s}`}function getSdkMetadataForEnvelopeHeader(e){if(!e||!e.sdk)return;const{name:t,version:n}=e.sdk;return{name:t,version:n}}function enhanceEventWithSdkInfo(e,t){if(!t)return e;e.sdk=e.sdk||{};e.sdk.name=e.sdk.name||t.name;e.sdk.version=e.sdk.version||t.version;e.sdk.integrations=[...e.sdk.integrations||[],...t.integrations||[]];e.sdk.packages=[...e.sdk.packages||[],...t.packages||[]];return e}function createSessionEnvelope(e,t,n,r){var s=getSdkMetadataForEnvelopeHeader(n);var i={sent_at:(new Date).toISOString(),...s&&{sdk:s},...!!r&&{dsn:o(t)}};var d="aggregates"in e?[{type:"sessions"},e]:[{type:"session"},e];return a(i,[d])}function createEventEnvelope(e,t,n,r){var s=getSdkMetadataForEnvelopeHeader(n);var i=e.type||"event";const{transactionSampling:o}=e.sdkProcessingMetadata||{};const{method:d,rate:_}=o||{};enhanceEventWithSdkInfo(e,n&&n.sdk);var p=createEventEnvelopeHeaders(e,s,r,t);delete e.sdkProcessingMetadata;var u=[{type:i,sample_rates:[{id:d,rate:_}]},e];return a(p,[u])}function createEventEnvelopeHeaders(e,t,n,r){var s=e.sdkProcessingMetadata&&e.sdkProcessingMetadata.baggage;var i=s&&_(s);return{event_id:e.event_id,sent_at:(new Date).toISOString(),...t&&{sdk:t},...!!n&&{dsn:o(r)},..."transaction"===e.type&&i&&{trace:d({...i})}}}var G=[];function filterDuplicates(e){return e.reduce(((e,t)=>{e.every((e=>t.name!==e.name))&&e.push(t);return e}),[])}function getIntegrationsToSetup(e){var t=e.defaultIntegrations&&[...e.defaultIntegrations]||[];var n=e.integrations;let r=[...filterDuplicates(t)];if(Array.isArray(n))r=[...r.filter((e=>n.every((t=>t.name!==e.name)))),...filterDuplicates(n)];else if("function"===typeof n){r=n(r);r=Array.isArray(r)?r:[r]}var s=r.map((e=>e.name));var i="Debug";-1!==s.indexOf(i)&&r.push(...r.splice(s.indexOf(i),1));return r}
/**
 * Given a list of integration instances this installs them all. When `withDefaults` is set to `true` then all default
 * integrations are added unless they were already provided before.
 * @param integrations array of integration instances
 * @param withDefault should enable default integrations
 */function setupIntegrations(n){var r={};n.forEach((n=>{r[n.name]=n;if(-1===G.indexOf(n.name)){n.setupOnce(e,t);G.push(n.name);("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.log(`Integration installed: ${n.name}`)}}));return r}var Y="Not capturing exception because it's already been captured.";class BaseClient{__init(){this._integrations={}}__init2(){this._integrationsInitialized=false}__init3(){this._numProcessing=0}__init4(){this._outcomes={}}
/**
   * Initializes this client instance.
   *
   * @param options Options for the client.
   */constructor(e){BaseClient.prototype.__init.call(this);BaseClient.prototype.__init2.call(this);BaseClient.prototype.__init3.call(this);BaseClient.prototype.__init4.call(this);this._options=e;if(e.dsn){this._dsn=i(e.dsn);var t=getEnvelopeEndpointWithUrlEncodedAuth(this._dsn,e);this._transport=e.transport({recordDroppedEvent:this.recordDroppedEvent.bind(this),...e.transportOptions,url:t})}else("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.warn("No DSN provided, client will not do anything.")}captureException(e,t,n){if(u(e)){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.log(Y);return}let r=t&&t.event_id;this._process(this.eventFromException(e,t).then((e=>this._captureEvent(e,t,n))).then((e=>{r=e})));return r}captureMessage(e,t,n,r){let s=n&&n.event_id;var i=l(e)?this.eventFromMessage(String(e),t,n):this.eventFromException(e,n);this._process(i.then((e=>this._captureEvent(e,n,r))).then((e=>{s=e})));return s}captureEvent(e,t,n){if(t&&t.originalException&&u(t.originalException)){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.log(Y);return}let r=t&&t.event_id;this._process(this._captureEvent(e,t,n).then((e=>{r=e})));return r}captureSession(e){if(this._isEnabled())if("string"===typeof e.release){this.sendSession(e);n(e,{init:false})}else("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.warn("Discarded session because of missing or non-string release");else("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.warn("SDK not enabled, will not capture session.")}getDsn(){return this._dsn}getOptions(){return this._options}getTransport(){return this._transport}flush(e){var t=this._transport;return t?this._isClientDoneProcessing(e).then((n=>t.flush(e).then((e=>n&&e)))):c(true)}close(e){return this.flush(e).then((e=>{this.getOptions().enabled=false;return e}))}setupIntegrations(){if(this._isEnabled()&&!this._integrationsInitialized){this._integrations=setupIntegrations(this._options.integrations);this._integrationsInitialized=true}}
/**
   * Gets an installed integration by its `id`.
   *
   * @returns The installed integration or `undefined` if no integration with that `id` was installed.
   */getIntegrationById(e){return this._integrations[e]}getIntegration(e){try{return this._integrations[e.id]||null}catch(t){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.warn(`Cannot retrieve integration ${e.id} from the current Client`);return null}}sendEvent(e,t={}){if(this._dsn){let r=createEventEnvelope(e,this._dsn,this._options._metadata,this._options.tunnel);for(var n of t.attachments||[])r=v(r,h(n,this._options.transportOptions&&this._options.transportOptions.textEncoder));this._sendEnvelope(r)}}sendSession(e){if(this._dsn){var t=createSessionEnvelope(e,this._dsn,this._options._metadata,this._options.tunnel);this._sendEnvelope(t)}}recordDroppedEvent(e,t){if(this._options.sendClientReports){var n=`${e}:${t}`;("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.log(`Adding outcome: "${n}"`);this._outcomes[n]=this._outcomes[n]+1||1}}_updateSessionFromEvent(e,t){let r=false;let s=false;var i=t.exception&&t.exception.values;if(i){s=true;for(var o of i){var a=o.mechanism;if(a&&false===a.handled){r=true;break}}}var d="ok"===e.status;var _=d&&0===e.errors||d&&r;if(_){n(e,{...r&&{status:"crashed"},errors:e.errors||Number(s||r)});this.captureSession(e)}}
/**
   * Determine if the client is finished processing. Returns a promise because it will wait `timeout` ms before saying
   * "no" (resolving to `false`) in order to give the client a chance to potentially finish first.
   *
   * @param timeout The time, in ms, after which to resolve to `false` if the client is still busy. Passing `0` (or not
   * passing anything) will make the promise wait as long as it takes for processing to finish before resolving to
   * `true`.
   * @returns A promise which will resolve to `true` if processing is already done or finishes before the timeout, and
   * `false` otherwise
   */_isClientDoneProcessing(e){return new f((t=>{let n=0;var r=1;var s=setInterval((()=>{if(0==this._numProcessing){clearInterval(s);t(true)}else{n+=r;if(e&&n>=e){clearInterval(s);t(false)}}}),r)}))}_isEnabled(){return false!==this.getOptions().enabled&&void 0!==this._dsn}
/**
   * Adds common information to events.
   *
   * The information includes release and environment from `options`,
   * breadcrumbs and context (extra, tags and user) from the scope.
   *
   * Information that is already present in the event is never overwritten. For
   * nested objects, such as the context, keys are merged.
   *
   * @param event The original event.
   * @param hint May contain additional information about the original exception.
   * @param scope A scope containing event metadata.
   * @returns A new event with more information.
   */_prepareEvent(e,t,n){const{normalizeDepth:s=3,normalizeMaxBreadth:i=1e3}=this.getOptions();var o={...e,event_id:e.event_id||t.event_id||g(),timestamp:e.timestamp||E()};this._applyClientOptions(o);this._applyIntegrationsMetadata(o);let a=n;t.captureContext&&(a=r.clone(a).update(t.captureContext));let d=c(o);if(a){var _=[...t.attachments||[],...a.getAttachments()];_.length&&(t.attachments=_);d=a.applyToEvent(o,t)}return d.then((e=>"number"===typeof s&&s>0?this._normalizeEvent(e,s,i):e))}
/**
   * Applies `normalize` function on necessary `Event` attributes to make them safe for serialization.
   * Normalized keys:
   * - `breadcrumbs.data`
   * - `user`
   * - `contexts`
   * - `extra`
   * @param event Event
   * @returns Normalized event
   */_normalizeEvent(e,t,n){if(!e)return null;var r={...e,...e.breadcrumbs&&{breadcrumbs:e.breadcrumbs.map((e=>({...e,...e.data&&{data:m(e.data,t,n)}})))},...e.user&&{user:m(e.user,t,n)},...e.contexts&&{contexts:m(e.contexts,t,n)},...e.extra&&{extra:m(e.extra,t,n)}};if(e.contexts&&e.contexts.trace&&r.contexts){r.contexts.trace=e.contexts.trace;e.contexts.trace.data&&(r.contexts.trace.data=m(e.contexts.trace.data,t,n))}e.spans&&(r.spans=e.spans.map((e=>{e.data&&(e.data=m(e.data,t,n));return e})));return r}
/**
   *  Enhances event using the client configuration.
   *  It takes care of all "static" values like environment, release and `dist`,
   *  as well as truncating overly long values.
   * @param event event instance to be enhanced
   */_applyClientOptions(e){var t=this.getOptions();const{environment:n,release:r,dist:s,maxValueLength:i=250}=t;"environment"in e||(e.environment="environment"in t?n:"production");void 0===e.release&&void 0!==r&&(e.release=r);void 0===e.dist&&void 0!==s&&(e.dist=s);e.message&&(e.message=S(e.message,i));var o=e.exception&&e.exception.values&&e.exception.values[0];o&&o.value&&(o.value=S(o.value,i));var a=e.request;a&&a.url&&(a.url=S(a.url,i))}
/**
   * This function adds all used integrations to the SDK info in the event.
   * @param event The event that will be filled with all integrations.
   */_applyIntegrationsMetadata(e){var t=Object.keys(this._integrations);if(t.length>0){e.sdk=e.sdk||{};e.sdk.integrations=[...e.sdk.integrations||[],...t]}}
/**
   * Processes the event and logs an error in case of rejection
   * @param event
   * @param hint
   * @param scope
   */_captureEvent(e,t={},n){return this._processEvent(e,t,n).then((e=>e.event_id),(e=>{if("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__){var t=e;"log"===t.logLevel?p.log(t.message):p.warn(t)}}))}
/**
   * Processes an event (either error or message) and sends it to Sentry.
   *
   * This also adds breadcrumbs and context information to the event. However,
   * platform specific meta data (such as the User's IP address) must be added
   * by the SDK implementor.
   *
   *
   * @param event The event to send to Sentry.
   * @param hint May contain additional information about the original exception.
   * @param scope A scope containing event metadata.
   * @returns A SyncPromise that resolves with the event or rejects in case event was/will not be send.
   */_processEvent(e,t,n){const{beforeSend:r,sampleRate:s}=this.getOptions();if(!this._isEnabled())return y(new b("SDK not enabled, will not capture event.","log"));var i="transaction"===e.type;if(!i&&"number"===typeof s&&Math.random()>s){this.recordDroppedEvent("sample_rate","error");return y(new b(`Discarding event because it's not included in the random sample (sampling rate = ${s})`,"log"))}return this._prepareEvent(e,t,n).then((n=>{if(null===n){this.recordDroppedEvent("event_processor",e.type||"error");throw new b("An event processor returned null, will not send event.","log")}var s=t.data&&true===t.data.__sentry__;if(s||i||!r)return n;var o=r(n,t);return _ensureBeforeSendRv(o)})).then((r=>{if(null===r){this.recordDroppedEvent("before_send",e.type||"error");throw new b("`beforeSend` returned `null`, will not send event.","log")}var s=n&&n.getSession();!i&&s&&this._updateSessionFromEvent(s,r);this.sendEvent(r,t);return r})).then(null,(e=>{if(e instanceof b)throw e;this.captureException(e,{data:{__sentry__:true},originalException:e});throw new b(`Event processing pipeline threw an error, original event will not be sent. Details have been sent as a new event.\nReason: ${e}`)}))}_process(e){this._numProcessing+=1;void e.then((e=>{this._numProcessing-=1;return e}),(e=>{this._numProcessing-=1;return e}))}_sendEnvelope(e){this._transport&&this._dsn?this._transport.send(e).then(null,(e=>{("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.error("Error while sending event:",e)})):("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.error("Transport disabled")}_clearOutcomes(){var e=this._outcomes;this._outcomes={};return Object.keys(e).map((t=>{const[n,r]=t.split(":");return{reason:n,category:r,quantity:e[t]}}))}}function _ensureBeforeSendRv(e){var t="`beforeSend` method has to return `null` or a valid event.";if(D(e))return e.then((e=>{if(!(x(e)||null===e))throw new b(t);return e}),(e=>{throw new b(`beforeSend rejected with ${e}`)}));if(!(x(e)||null===e))throw new b(t);return e}var C=30;
/**
 * Creates an instance of a Sentry `Transport`
 *
 * @param options
 * @param makeRequest
 */function createTransport(e,t,n=B(e.bufferSize||C)){let r={};var flush=e=>n.drain(e);function send(s){var i=[];k(s,((t,n)=>{var s=T(n);w(r,s)?e.recordDroppedEvent("ratelimit_backoff",s):i.push(t)}));if(0===i.length)return c();var o=a(s[0],i);var recordEnvelopeLoss=t=>{k(o,((n,r)=>{e.recordDroppedEvent(t,T(r))}))};var requestTask=()=>t({body:R(o,e.textEncoder)}).then((e=>{void 0!==e.statusCode&&(e.statusCode<200||e.statusCode>=300)&&("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.warn(`Sentry responded with status code ${e.statusCode} to sent event.`);r=U(r,e)}),(e=>{("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.error("Failed while sending event:",e);recordEnvelopeLoss("network_error")}));return n.add(requestTask).then((e=>e),(e=>{if(e instanceof b){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&p.error("Skipped sending event due to full buffer");recordEnvelopeLoss("queue_overflow");return c()}throw e}))}return{send:send,flush:flush}}var O="7.11.1";var A=Object.freeze(Object.defineProperty({__proto__:null,FunctionToString:I,InboundFilters:N},Symbol.toStringTag,{value:"Module"}));export{BaseClient,A as Integrations,O as SDK_VERSION,createTransport,getEnvelopeEndpointWithUrlEncodedAuth,getIntegrationsToSetup,getReportDialogEndpoint};


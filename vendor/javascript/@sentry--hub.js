import{timestampInSeconds as t,uuid4 as e,dropUndefinedKeys as s,isPlainObject as r,dateTimestampInSeconds as i,getGlobalSingleton as n,SyncPromise as a,logger as o,isThenable as u,consoleSandbox as c,getGlobalObject as h,isNodeEnv as _}from"@sentry/utils";
/**
 * Creates a new `Session` object by setting certain default parameters. If optional @param context
 * is passed, the passed properties are applied to the session object.
 *
 * @param context (optional) additional properties to be applied to the returned session object
 *
 * @returns a new `Session` object
 */function makeSession(s){var r=t();var i={sid:e(),init:true,timestamp:r,started:r,duration:0,status:"ok",errors:0,ignoreDuration:false,toJSON:()=>sessionToJSON(i)};s&&updateSession(i,s);return i}
/**
 * Updates a session object with the properties passed in the context.
 *
 * Note that this function mutates the passed object and returns void.
 * (Had to do this instead of returning a new and updated session because closing and sending a session
 * makes an update to the session after it was passed to the sending logic.
 * @see BaseClient.captureSession )
 *
 * @param session the `Session` to update
 * @param context the `SessionContext` holding the properties that should be updated in @param session
 */function updateSession(s,r={}){if(r.user){!s.ipAddress&&r.user.ip_address&&(s.ipAddress=r.user.ip_address);s.did||r.did||(s.did=r.user.id||r.user.email||r.user.username)}s.timestamp=r.timestamp||t();r.ignoreDuration&&(s.ignoreDuration=r.ignoreDuration);r.sid&&(s.sid=32===r.sid.length?r.sid:e());void 0!==r.init&&(s.init=r.init);!s.did&&r.did&&(s.did=`${r.did}`);"number"===typeof r.started&&(s.started=r.started);if(s.ignoreDuration)s.duration=void 0;else if("number"===typeof r.duration)s.duration=r.duration;else{var i=s.timestamp-s.started;s.duration=i>=0?i:0}r.release&&(s.release=r.release);r.environment&&(s.environment=r.environment);!s.ipAddress&&r.ipAddress&&(s.ipAddress=r.ipAddress);!s.userAgent&&r.userAgent&&(s.userAgent=r.userAgent);"number"===typeof r.errors&&(s.errors=r.errors);r.status&&(s.status=r.status)}
/**
 * Closes a session by setting its status and updating the session object with it.
 * Internally calls `updateSession` to update the passed session object.
 *
 * Note that this function mutates the passed session (@see updateSession for explanation).
 *
 * @param session the `Session` object to be closed
 * @param status the `SessionStatus` with which the session was closed. If you don't pass a status,
 *               this function will keep the previously set status, unless it was `'ok'` in which case
 *               it is changed to `'exited'`.
 */function closeSession(t,e){let s={};e?s={status:e}:"ok"===t.status&&(s={status:"exited"});updateSession(t,s)}
/**
 * Serializes a passed session object to a JSON object with a slightly different structure.
 * This is necessary because the Sentry backend requires a slightly different schema of a session
 * than the one the JS SDKs use internally.
 *
 * @param session the session to be converted
 *
 * @returns a JSON object of the passed session
 */function sessionToJSON(t){return s({sid:`${t.sid}`,init:t.init,started:new Date(1e3*t.started).toISOString(),timestamp:new Date(1e3*t.timestamp).toISOString(),status:t.status,errors:t.errors,did:"number"===typeof t.did||"string"===typeof t.did?`${t.did}`:void 0,duration:t.duration,attrs:{release:t.release,environment:t.environment,ip_address:t.ipAddress,user_agent:t.userAgent}})}var g=100;class Scope{constructor(){this._notifyingListeners=false;this._scopeListeners=[];this._eventProcessors=[];this._breadcrumbs=[];this._attachments=[];this._user={};this._tags={};this._extra={};this._contexts={};this._sdkProcessingMetadata={}}
/**
   * Inherit values from the parent scope.
   * @param scope to clone.
   */static clone(t){var e=new Scope;if(t){e._breadcrumbs=[...t._breadcrumbs];e._tags={...t._tags};e._extra={...t._extra};e._contexts={...t._contexts};e._user=t._user;e._level=t._level;e._span=t._span;e._session=t._session;e._transactionName=t._transactionName;e._fingerprint=t._fingerprint;e._eventProcessors=[...t._eventProcessors];e._requestSession=t._requestSession;e._attachments=[...t._attachments]}return e}addScopeListener(t){this._scopeListeners.push(t)}addEventProcessor(t){this._eventProcessors.push(t);return this}setUser(t){this._user=t||{};this._session&&updateSession(this._session,{user:t});this._notifyScopeListeners();return this}getUser(){return this._user}getRequestSession(){return this._requestSession}setRequestSession(t){this._requestSession=t;return this}setTags(t){this._tags={...this._tags,...t};this._notifyScopeListeners();return this}setTag(t,e){this._tags={...this._tags,[t]:e};this._notifyScopeListeners();return this}setExtras(t){this._extra={...this._extra,...t};this._notifyScopeListeners();return this}setExtra(t,e){this._extra={...this._extra,[t]:e};this._notifyScopeListeners();return this}setFingerprint(t){this._fingerprint=t;this._notifyScopeListeners();return this}setLevel(t){this._level=t;this._notifyScopeListeners();return this}setTransactionName(t){this._transactionName=t;this._notifyScopeListeners();return this}setContext(t,e){null===e?delete this._contexts[t]:this._contexts={...this._contexts,[t]:e};this._notifyScopeListeners();return this}setSpan(t){this._span=t;this._notifyScopeListeners();return this}getSpan(){return this._span}getTransaction(){var t=this.getSpan();return t&&t.transaction}setSession(t){t?this._session=t:delete this._session;this._notifyScopeListeners();return this}getSession(){return this._session}update(t){if(!t)return this;if("function"===typeof t){var e=t(this);return e instanceof Scope?e:this}if(t instanceof Scope){this._tags={...this._tags,...t._tags};this._extra={...this._extra,...t._extra};this._contexts={...this._contexts,...t._contexts};t._user&&Object.keys(t._user).length&&(this._user=t._user);t._level&&(this._level=t._level);t._fingerprint&&(this._fingerprint=t._fingerprint);t._requestSession&&(this._requestSession=t._requestSession)}else if(r(t)){t=t;this._tags={...this._tags,...t.tags};this._extra={...this._extra,...t.extra};this._contexts={...this._contexts,...t.contexts};t.user&&(this._user=t.user);t.level&&(this._level=t.level);t.fingerprint&&(this._fingerprint=t.fingerprint);t.requestSession&&(this._requestSession=t.requestSession)}return this}clear(){this._breadcrumbs=[];this._tags={};this._extra={};this._user={};this._contexts={};this._level=void 0;this._transactionName=void 0;this._fingerprint=void 0;this._requestSession=void 0;this._span=void 0;this._session=void 0;this._notifyScopeListeners();this._attachments=[];return this}addBreadcrumb(t,e){var s="number"===typeof e?Math.min(e,g):g;if(s<=0)return this;var r={timestamp:i(),...t};this._breadcrumbs=[...this._breadcrumbs,r].slice(-s);this._notifyScopeListeners();return this}clearBreadcrumbs(){this._breadcrumbs=[];this._notifyScopeListeners();return this}addAttachment(t){this._attachments.push(t);return this}getAttachments(){return this._attachments}clearAttachments(){this._attachments=[];return this}
/**
   * Applies the current context and fingerprint to the event.
   * Note that breadcrumbs will be added by the client.
   * Also if the event has already breadcrumbs on it, we do not merge them.
   * @param event Event
   * @param hint May contain additional information about the original exception.
   * @hidden
   */applyToEvent(t,e={}){this._extra&&Object.keys(this._extra).length&&(t.extra={...this._extra,...t.extra});this._tags&&Object.keys(this._tags).length&&(t.tags={...this._tags,...t.tags});this._user&&Object.keys(this._user).length&&(t.user={...this._user,...t.user});this._contexts&&Object.keys(this._contexts).length&&(t.contexts={...this._contexts,...t.contexts});this._level&&(t.level=this._level);this._transactionName&&(t.transaction=this._transactionName);if(this._span){t.contexts={trace:this._span.getTraceContext(),...t.contexts};var s=this._span.transaction&&this._span.transaction.name;s&&(t.tags={transaction:s,...t.tags})}this._applyFingerprint(t);t.breadcrumbs=[...t.breadcrumbs||[],...this._breadcrumbs];t.breadcrumbs=t.breadcrumbs.length>0?t.breadcrumbs:void 0;t.sdkProcessingMetadata={...t.sdkProcessingMetadata,...this._sdkProcessingMetadata};return this._notifyEventProcessors([...getGlobalEventProcessors(),...this._eventProcessors],t,e)}setSDKProcessingMetadata(t){this._sdkProcessingMetadata={...this._sdkProcessingMetadata,...t};return this}_notifyEventProcessors(t,e,s,r=0){return new a(((i,n)=>{var a=t[r];if(null===e||"function"!==typeof a)i(e);else{var c=a({...e},s);("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&a.id&&null===c&&o.log(`Event processor "${a.id}" dropped event`);u(c)?void c.then((e=>this._notifyEventProcessors(t,e,s,r+1).then(i))).then(null,n):void this._notifyEventProcessors(t,c,s,r+1).then(i).then(null,n)}}))}_notifyScopeListeners(){if(!this._notifyingListeners){this._notifyingListeners=true;this._scopeListeners.forEach((t=>{t(this)}));this._notifyingListeners=false}}_applyFingerprint(t){t.fingerprint=t.fingerprint?Array.isArray(t.fingerprint)?t.fingerprint:[t.fingerprint]:[];this._fingerprint&&(t.fingerprint=t.fingerprint.concat(this._fingerprint));t.fingerprint&&!t.fingerprint.length&&delete t.fingerprint}}function getGlobalEventProcessors(){return n("globalEventProcessors",(()=>[]))}
/**
 * Add a EventProcessor to be kept globally.
 * @param callback EventProcessor to add
 */function addGlobalEventProcessor(t){getGlobalEventProcessors().push(t)}var d=4;var p=100;class Hub{__init(){this._stack=[{}]}
/**
   * Creates a new instance of the hub, will push one {@link Layer} into the
   * internal stack on creation.
   *
   * @param client bound to the hub.
   * @param scope bound to the hub.
   * @param version number, higher number means higher priority.
   */constructor(t,e=new Scope,s=d){this._version=s;Hub.prototype.__init.call(this);this.getStackTop().scope=e;t&&this.bindClient(t)}isOlderThan(t){return this._version<t}bindClient(t){var e=this.getStackTop();e.client=t;t&&t.setupIntegrations&&t.setupIntegrations()}pushScope(){var t=Scope.clone(this.getScope());this.getStack().push({client:this.getClient(),scope:t});return t}popScope(){return!(this.getStack().length<=1)&&!!this.getStack().pop()}withScope(t){var e=this.pushScope();try{t(e)}finally{this.popScope()}}getClient(){return this.getStackTop().client}getScope(){return this.getStackTop().scope}getStack(){return this._stack}getStackTop(){return this._stack[this._stack.length-1]}captureException(t,s){var r=this._lastEventId=s&&s.event_id?s.event_id:e();var i=new Error("Sentry syntheticException");this._withClient(((e,n)=>{e.captureException(t,{originalException:t,syntheticException:i,...s,event_id:r},n)}));return r}captureMessage(t,s,r){var i=this._lastEventId=r&&r.event_id?r.event_id:e();var n=new Error(t);this._withClient(((e,a)=>{e.captureMessage(t,s,{originalException:t,syntheticException:n,...r,event_id:i},a)}));return i}captureEvent(t,s){var r=s&&s.event_id?s.event_id:e();"transaction"!==t.type&&(this._lastEventId=r);this._withClient(((e,i)=>{e.captureEvent(t,{...s,event_id:r},i)}));return r}lastEventId(){return this._lastEventId}addBreadcrumb(t,e){const{scope:s,client:r}=this.getStackTop();if(!s||!r)return;const{beforeBreadcrumb:n=null,maxBreadcrumbs:a=p}=r.getOptions&&r.getOptions()||{};if(!(a<=0)){var o=i();var u={timestamp:o,...t};var h=n?c((()=>n(u,e))):u;null!==h&&s.addBreadcrumb(h,a)}}setUser(t){var e=this.getScope();e&&e.setUser(t)}setTags(t){var e=this.getScope();e&&e.setTags(t)}setExtras(t){var e=this.getScope();e&&e.setExtras(t)}setTag(t,e){var s=this.getScope();s&&s.setTag(t,e)}setExtra(t,e){var s=this.getScope();s&&s.setExtra(t,e)}setContext(t,e){var s=this.getScope();s&&s.setContext(t,e)}configureScope(t){const{scope:e,client:s}=this.getStackTop();e&&s&&t(e)}run(t){var e=makeMain(this);try{t(this)}finally{makeMain(e)}}getIntegration(t){var e=this.getClient();if(!e)return null;try{return e.getIntegration(t)}catch(e){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&o.warn(`Cannot retrieve integration ${t.id} from the current Hub`);return null}}startTransaction(t,e){return this._callExtensionMethod("startTransaction",t,e)}traceHeaders(){return this._callExtensionMethod("traceHeaders")}captureSession(t=false){if(t)return this.endSession();this._sendSessionUpdate()}endSession(){var t=this.getStackTop();var e=t&&t.scope;var s=e&&e.getSession();s&&closeSession(s);this._sendSessionUpdate();e&&e.setSession()}startSession(t){const{scope:e,client:s}=this.getStackTop();const{release:r,environment:i}=s&&s.getOptions()||{};var n=h();const{userAgent:a}=n.navigator||{};var o=makeSession({release:r,environment:i,...e&&{user:e.getUser()},...a&&{userAgent:a},...t});if(e){var u=e.getSession&&e.getSession();u&&"ok"===u.status&&updateSession(u,{status:"exited"});this.endSession();e.setSession(o)}return o}shouldSendDefaultPii(){var t=this.getClient();var e=t&&t.getOptions();return Boolean(e&&e.sendDefaultPii)}_sendSessionUpdate(){const{scope:t,client:e}=this.getStackTop();if(t){var s=t.getSession();s&&e&&e.captureSession&&e.captureSession(s)}}
/**
   * Internal helper function to call a method on the top client if it exists.
   *
   * @param method The method to call on the client.
   * @param args Arguments to pass to the client function.
   */_withClient(t){const{scope:e,client:s}=this.getStackTop();s&&t(s,e)}_callExtensionMethod(t,...e){var s=getMainCarrier();var r=s.__SENTRY__;if(r&&r.extensions&&"function"===typeof r.extensions[t])return r.extensions[t].apply(this,e);("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&o.warn(`Extension method ${t} couldn't be found, doing nothing.`)}}function getMainCarrier(){var t=h();t.__SENTRY__=t.__SENTRY__||{extensions:{},hub:void 0};return t}
/**
 * Replaces the current main hub with the passed one on the global object
 *
 * @returns The old replaced hub
 */function makeMain(t){var e=getMainCarrier();var s=getHubFromCarrier(e);setHubOnCarrier(e,t);return s}function getCurrentHub(){var t=getMainCarrier();hasHubOnCarrier(t)&&!getHubFromCarrier(t).isOlderThan(d)||setHubOnCarrier(t,new Hub);return _()?getHubFromActiveDomain(t):getHubFromCarrier(t)}
/**
 * Try to read the hub from an active domain, and fallback to the registry if one doesn't exist
 * @returns discovered hub
 */function getHubFromActiveDomain(t){try{var e=getMainCarrier().__SENTRY__;var s=e&&e.extensions&&e.extensions.domain&&e.extensions.domain.active;if(!s)return getHubFromCarrier(t);if(!hasHubOnCarrier(s)||getHubFromCarrier(s).isOlderThan(d)){var r=getHubFromCarrier(t).getStackTop();setHubOnCarrier(s,new Hub(r.client,Scope.clone(r.scope)))}return getHubFromCarrier(s)}catch(e){return getHubFromCarrier(t)}}
/**
 * This will tell whether a carrier has a hub on it or not
 * @param carrier object
 */function hasHubOnCarrier(t){return!!(t&&t.__SENTRY__&&t.__SENTRY__.hub)}
/**
 * This will create a new {@link Hub} and add to the passed object on
 * __SENTRY__.hub.
 * @param carrier object
 * @hidden
 */function getHubFromCarrier(t){return n("hub",(()=>new Hub),t)}
/**
 * This will set passed {@link Hub} on the passed object's __SENTRY__.hub attribute
 * @param carrier object
 * @param hub Hub
 * @returns A boolean indicating success or failure
 */function setHubOnCarrier(t,e){if(!t)return false;var s=t.__SENTRY__=t.__SENTRY__||{};s.hub=e;return true}class SessionFlusher{__init(){this.flushTimeout=60}__init2(){this._pendingAggregates={}}__init3(){this._isEnabled=true}constructor(t,e){SessionFlusher.prototype.__init.call(this);SessionFlusher.prototype.__init2.call(this);SessionFlusher.prototype.__init3.call(this);this._client=t;this._intervalId=setInterval((()=>this.flush()),1e3*this.flushTimeout);this._sessionAttrs=e}flush(){var t=this.getSessionAggregates();if(0!==t.aggregates.length){this._pendingAggregates={};this._client.sendSession(t)}}getSessionAggregates(){var t=Object.keys(this._pendingAggregates).map((t=>this._pendingAggregates[parseInt(t)]));var e={attrs:this._sessionAttrs,aggregates:t};return s(e)}close(){clearInterval(this._intervalId);this._isEnabled=false;this.flush()}incrementSessionStatusCount(){if(this._isEnabled){var t=getCurrentHub().getScope();var e=t&&t.getRequestSession();if(e&&e.status){this._incrementSessionStatusCount(e.status,new Date);t&&t.setRequestSession(void 0)}}}_incrementSessionStatusCount(t,e){var s=new Date(e).setSeconds(0,0);this._pendingAggregates[s]=this._pendingAggregates[s]||{};var r=this._pendingAggregates[s];r.started||(r.started=new Date(s).toISOString());switch(t){case"errored":r.errored=(r.errored||0)+1;return r.errored;case"ok":r.exited=(r.exited||0)+1;return r.exited;default:r.crashed=(r.crashed||0)+1;return r.crashed}}}
/**
 * Captures an exception event and sends it to Sentry.
 *
 * @param exception An exception-like object.
 * @param captureContext Additional scope data to apply to exception event.
 * @returns The generated eventId.
 */function captureException(t,e){return getCurrentHub().captureException(t,{captureContext:e})}
/**
 * Captures a message event and sends it to Sentry.
 *
 * @param message The message to send to Sentry.
 * @param Severity Define the level of the message.
 * @returns The generated eventId.
 */function captureMessage(t,e){var s="string"===typeof e?e:void 0;var r="string"!==typeof e?{captureContext:e}:void 0;return getCurrentHub().captureMessage(t,s,r)}
/**
 * Captures a manually created event and sends it to Sentry.
 *
 * @param event The event to send to Sentry.
 * @returns The generated eventId.
 */function captureEvent(t,e){return getCurrentHub().captureEvent(t,e)}
/**
 * Callback to set context information onto the scope.
 * @param callback Callback function that receives Scope.
 */function configureScope(t){getCurrentHub().configureScope(t)}
/**
 * Records a new breadcrumb which will be attached to future events.
 *
 * Breadcrumbs will be added to subsequent events to provide more context on
 * user's actions prior to an error or crash.
 *
 * @param breadcrumb The breadcrumb to record.
 */function addBreadcrumb(t){getCurrentHub().addBreadcrumb(t)}
/**
 * Sets context data with the given name.
 * @param name of the context
 * @param context Any kind of data. This data will be normalized.
 */function setContext(t,e){getCurrentHub().setContext(t,e)}
/**
 * Set an object that will be merged sent as extra data with the event.
 * @param extras Extras object to merge into current context.
 */function setExtras(t){getCurrentHub().setExtras(t)}
/**
 * Set key:value that will be sent as extra data with the event.
 * @param key String of extra
 * @param extra Any kind of data. This data will be normalized.
 */function setExtra(t,e){getCurrentHub().setExtra(t,e)}
/**
 * Set an object that will be merged sent as tags data with the event.
 * @param tags Tags context object to merge into current context.
 */function setTags(t){getCurrentHub().setTags(t)}
/**
 * Set key:value that will be sent as tags data with the event.
 *
 * Can also be used to unset a tag, by passing `undefined`.
 *
 * @param key String key of tag
 * @param value Value of tag
 */function setTag(t,e){getCurrentHub().setTag(t,e)}
/**
 * Updates user context information for future events.
 *
 * @param user User context object to be set in the current context. Pass `null` to unset the user.
 */function setUser(t){getCurrentHub().setUser(t)}
/**
 * Creates a new scope with and executes the given operation within.
 * The scope is automatically removed once the operation
 * finishes or throws.
 *
 * This is essentially a convenience function for:
 *
 *     pushScope();
 *     callback();
 *     popScope();
 *
 * @param callback that will be enclosed into push/popScope.
 */function withScope(t){getCurrentHub().withScope(t)}
/**
 * Starts a new `Transaction` and returns it. This is the entry point to manual tracing instrumentation.
 *
 * A tree structure can be built by adding child spans to the transaction, and child spans to other spans. To start a
 * new child span within the transaction or any span, call the respective `.startChild()` method.
 *
 * Every child span must be finished before the transaction is finished, otherwise the unfinished spans are discarded.
 *
 * The transaction must be finished with a call to its `.finish()` method, at which point the transaction with all its
 * finished child spans will be sent to Sentry.
 *
 * NOTE: This function should only be used for *manual* instrumentation. Auto-instrumentation should call
 * `startTransaction` directly on the hub.
 *
 * @param context Properties of the new `Transaction`.
 * @param customSamplingContext Information given to the transaction sampling function (along with context-dependent
 * default values). See {@link Options.tracesSampler}.
 *
 * @returns The transaction which was just started
 */function startTransaction(t,e){return getCurrentHub().startTransaction({metadata:{source:"custom"},...t},e)}export{Hub,Scope,SessionFlusher,addBreadcrumb,addGlobalEventProcessor,captureEvent,captureException,captureMessage,closeSession,configureScope,getCurrentHub,getHubFromCarrier,getMainCarrier,makeMain,makeSession,setContext,setExtra,setExtras,setHubOnCarrier,setTag,setTags,setUser,startTransaction,updateSession,withScope};


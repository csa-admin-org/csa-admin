import{f as t,c as r,d as n}from"../_/bd205728.js";export{a as addNonEnumerableProperty,c as convertToPlainObject,d as dropUndefinedKeys,e as extractExceptionKeysForMessage,f as fill,g as getLocationHref,b as getOriginalFunction,h as htmlTreeAsString,m as markFunctionWrapped,o as objectify,u as urlEncode}from"../_/bd205728.js";import{g as s,d as p,i as v}from"../_/44904228.js";export{d as dynamicRequire,g as getGlobalObject,a as getGlobalSingleton,b as isBrowserBundle,i as isNodeEnv,l as loadModule}from"../_/44904228.js";import{isInstanceOf as y,isString as _,isNaN as E,isSyntheticEvent as S,isThenable as D,isPlainObject as w}from"./is.js";export{isDOMError,isDOMException,isElement,isError,isErrorEvent,isEvent,isInstanceOf,isNaN,isPlainObject,isPrimitive,isRegExp,isString,isSyntheticEvent,isThenable}from"./is.js";import{logger as R,CONSOLE_LEVELS as P}from"./logger.js";export{CONSOLE_LEVELS,consoleSandbox,logger}from"./logger.js";import{_optionalChain as T}from"./buildPolyfills/index.js";import{supportsNativeFetch as k,supportsHistory as x}from"./supports.js";export{isNativeFetch,supportsDOMError,supportsDOMException,supportsErrorEvent,supportsFetch,supportsHistory,supportsNativeFetch,supportsReferrerPolicy,supportsReportingObserver}from"./supports.js";export{addContextToFrame,addExceptionMechanism,addExceptionTypeValue,checkOrSetAlreadyCaught,getEventDescription,parseSemver,uuid4}from"./misc.js";export{basename,dirname,isAbsolute,join,normalizePath,relative,resolve}from"./path.js";export{escapeStringForRegex,isMatchingPattern,safeJoin,snipLine,truncate}from"./string.js";class SentryError extends Error{constructor(e,t="warn"){super(e);this.message=e;this.name=new.target.prototype.constructor.name;Object.setPrototypeOf(this,new.target.prototype);this.logLevel=t}}var N=/^(?:(\w+):)\/\/(?:(\w+)(?::(\w+))?@)([\w.-]+)(?::(\d+))?\/(.+)/;function isValidProtocol(e){return"http"===e||"https"===e}
/**
 * Renders the string representation of this Dsn.
 *
 * By default, this will render the public representation without the password
 * component. To get the deprecated private representation, set `withPassword`
 * to true.
 *
 * @param withPassword When set to true, the password will be included.
 */function dsnToString(e,t=false){const{host:r,path:n,pass:a,port:i,projectId:o,protocol:s,publicKey:u}=e;return`${s}://${u}${t&&a?`:${a}`:""}@${r}${i?`:${i}`:""}/${n?`${n}/`:n}${o}`}
/**
 * Parses a Dsn from a given string.
 *
 * @param str A Dsn as string
 * @returns Dsn as DsnComponents
 */function dsnFromString(e){var t=N.exec(e);if(!t)throw new SentryError(`Invalid Sentry Dsn: ${e}`);const[r,n,a="",i,o="",s]=t.slice(1);let u="";let c=s;var l=c.split("/");if(l.length>1){u=l.slice(0,-1).join("/");c=l.pop()}if(c){var f=c.match(/^\d+/);f&&(c=f[0])}return dsnFromComponents({host:i,pass:a,path:u,projectId:c,port:o,protocol:r,publicKey:n})}function dsnFromComponents(e){return{protocol:e.protocol,publicKey:e.publicKey||"",pass:e.pass||"",host:e.host,port:e.port||"",path:e.path||"",projectId:e.projectId}}function validateDsn(e){if(!("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__))return;const{port:t,projectId:r,protocol:n}=e;var a=["protocol","publicKey","host","projectId"];a.forEach((t=>{if(!e[t])throw new SentryError(`Invalid Sentry Dsn: ${t} missing`)}));if(!r.match(/^\d+$/))throw new SentryError(`Invalid Sentry Dsn: Invalid projectId ${r}`);if(!isValidProtocol(n))throw new SentryError(`Invalid Sentry Dsn: Invalid protocol ${n}`);if(t&&isNaN(parseInt(t,10)))throw new SentryError(`Invalid Sentry Dsn: Invalid port ${t}`);return true}function makeDsn(e){var t="string"===typeof e?dsnFromString(e):dsnFromComponents(e);validateDsn(t);return t}var O=50;function createStackParser(...e){var t=e.sort(((e,t)=>e[0]-t[0])).map((e=>e[1]));return(e,r=0)=>{var n=[];for(var a of e.split("\n").slice(r)){var i=a.replace(/\(error: (.*)\)/,"$1");for(var o of t){var s=o(i);if(s){n.push(s);break}}}return stripSentryFramesAndReverse(n)}}function stackParserFromStackParserOptions(e){return Array.isArray(e)?createStackParser(...e):e}function stripSentryFramesAndReverse(e){if(!e.length)return[];let t=e;var r=t[0].function||"";var n=t[t.length-1].function||"";-1===r.indexOf("captureMessage")&&-1===r.indexOf("captureException")||(t=t.slice(1));-1!==n.indexOf("sentryWrapped")&&(t=t.slice(0,-1));return t.slice(0,O).map((e=>({...e,filename:e.filename||t[0].filename,function:e.function||"?"}))).reverse()}var B="<anonymous>";function getFunctionName(e){try{return e&&"function"===typeof e&&e.name||B}catch(e){return B}}function node(e){var t=/^\s*[-]{4,}$/;var r=/at (?:async )?(?:(.+?)\s+\()?(?:(.+):(\d+):(\d+)?|([^)]+))\)?/;return n=>{if(n.match(t))return{filename:n};var a=n.match(r);if(!a)return;let i;let o;let s;let u;let c;if(a[1]){s=a[1];let e=s.lastIndexOf(".");"."===s[e-1]&&e--;if(e>0){i=s.substr(0,e);o=s.substr(e+1);var l=i.indexOf(".Module");if(l>0){s=s.substr(l+1);i=i.substr(0,l)}}u=void 0}if(o){u=i;c=o}if("<anonymous>"===o){c=void 0;s=void 0}if(void 0===s){c=c||"<anonymous>";s=u?`${u}.${c}`:c}var f=T([a,"access",e=>e[2],"optionalAccess",e=>e.startsWith,"call",e=>e("file://")])?a[2].substr(7):a[2];var d="native"===a[5];var p=d||f&&!f.startsWith("/")&&!f.startsWith(".")&&1!==f.indexOf(":\\");var m=!p&&void 0!==f&&!f.includes("node_modules/");return{filename:f,module:T([e,"optionalCall",e=>e(f)]),function:s,lineno:parseInt(a[3],10)||void 0,colno:parseInt(a[4],10)||void 0,in_app:m}}}function nodeStackLineParser(e){return[90,node(e)]}var I=s();var j={};var U={};function instrument(e){if(!U[e]){U[e]=true;switch(e){case"console":instrumentConsole();break;case"dom":instrumentDOM();break;case"xhr":instrumentXHR();break;case"fetch":instrumentFetch();break;case"history":instrumentHistory();break;case"error":instrumentError();break;case"unhandledrejection":instrumentUnhandledRejection();break;default:("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&R.warn("unknown instrumentation type:",e);return}}}function addInstrumentationHandler(e,t){j[e]=j[e]||[];j[e].push(t);instrument(e)}function triggerHandlers(e,t){if(e&&j[e])for(var r of j[e]||[])try{r(t)}catch(t){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&R.error(`Error while triggering instrumentation handler.\nType: ${e}\nName: ${getFunctionName(r)}\nError:`,t)}}function instrumentConsole(){"console"in I&&P.forEach((function(e){e in I.console&&t(I.console,e,(function(t){return function(...r){triggerHandlers("console",{args:r,level:e});t&&t.apply(I.console,r)}}))}))}function instrumentFetch(){k()&&t(I,"fetch",(function(e){return function(...t){var r={args:t,fetchData:{method:getFetchMethod(t),url:getFetchUrl(t)},startTimestamp:Date.now()};triggerHandlers("fetch",{...r});return e.apply(I,t).then((e=>{triggerHandlers("fetch",{...r,endTimestamp:Date.now(),response:e});return e}),(e=>{triggerHandlers("fetch",{...r,endTimestamp:Date.now(),error:e});throw e}))}}))}function getFetchMethod(e=[]){return"Request"in I&&y(e[0],Request)&&e[0].method?String(e[0].method).toUpperCase():e[1]&&e[1].method?String(e[1].method).toUpperCase():"GET"}function getFetchUrl(e=[]){return"string"===typeof e[0]?e[0]:"Request"in I&&y(e[0],Request)?e[0].url:String(e[0])}function instrumentXHR(){if("XMLHttpRequest"in I){var e=XMLHttpRequest.prototype;t(e,"open",(function(e){return function(...r){var n=this;var a=r[1];var i=n.__sentry_xhr__={method:_(r[0])?r[0].toUpperCase():r[0],url:r[1]};_(a)&&"POST"===i.method&&a.match(/sentry_key/)&&(n.__sentry_own_request__=true);var onreadystatechangeHandler=function(){if(4===n.readyState){try{i.status_code=n.status}catch(e){}triggerHandlers("xhr",{args:r,endTimestamp:Date.now(),startTimestamp:Date.now(),xhr:n})}};"onreadystatechange"in n&&"function"===typeof n.onreadystatechange?t(n,"onreadystatechange",(function(e){return function(...t){onreadystatechangeHandler();return e.apply(n,t)}})):n.addEventListener("readystatechange",onreadystatechangeHandler);return e.apply(n,r)}}));t(e,"send",(function(e){return function(...t){this.__sentry_xhr__&&void 0!==t[0]&&(this.__sentry_xhr__.body=t[0]);triggerHandlers("xhr",{args:t,startTimestamp:Date.now(),xhr:this});return e.apply(this,t)}}))}}let F;function instrumentHistory(){if(x()){var e=I.onpopstate;I.onpopstate=function(...t){var r=I.location.href;var n=F;F=r;triggerHandlers("history",{from:n,to:r});if(e)try{return e.apply(this,t)}catch(e){}};t(I.history,"pushState",historyReplacementFunction);t(I.history,"replaceState",historyReplacementFunction)}function historyReplacementFunction(e){return function(...t){var r=t.length>2?t[2]:void 0;if(r){var n=F;var a=String(r);F=a;triggerHandlers("history",{from:n,to:a})}return e.apply(this,t)}}}var $=1e3;let H;let A;
/**
 * Decide whether the current event should finish the debounce of previously captured one.
 * @param previous previously captured event
 * @param current event to be captured
 */function shouldShortcircuitPreviousDebounce(e,t){if(!e)return true;if(e.type!==t.type)return true;try{if(e.target!==t.target)return true}catch(e){}return false}
/**
 * Decide whether an event should be captured.
 * @param event event to be captured
 */function shouldSkipDOMEvent(e){if("keypress"!==e.type)return false;try{var t=e.target;if(!t||!t.tagName)return true;if("INPUT"===t.tagName||"TEXTAREA"===t.tagName||t.isContentEditable)return false}catch(e){}return true}
/**
 * Wraps addEventListener to capture UI breadcrumbs
 * @param handler function that will be triggered
 * @param globalListener indicates whether event was captured by the global event listener
 * @returns wrapped breadcrumb events handler
 * @hidden
 */function makeDOMEventHandler(e,t=false){return r=>{if(r&&A!==r&&!shouldSkipDOMEvent(r)){var n="keypress"===r.type?"input":r.type;if(void 0===H){e({event:r,name:n,global:t});A=r}else if(shouldShortcircuitPreviousDebounce(A,r)){e({event:r,name:n,global:t});A=r}clearTimeout(H);H=I.setTimeout((()=>{H=void 0}),$)}}}function instrumentDOM(){if("document"in I){var e=triggerHandlers.bind(null,"dom");var r=makeDOMEventHandler(e,true);I.document.addEventListener("click",r,false);I.document.addEventListener("keypress",r,false);["EventTarget","Node"].forEach((r=>{var n=I[r]&&I[r].prototype;if(n&&n.hasOwnProperty&&n.hasOwnProperty("addEventListener")){t(n,"addEventListener",(function(t){return function(r,n,a){if("click"===r||"keypress"==r)try{var i=this;var o=i.__sentry_instrumentation_handlers__=i.__sentry_instrumentation_handlers__||{};var s=o[r]=o[r]||{refCount:0};if(!s.handler){var u=makeDOMEventHandler(e);s.handler=u;t.call(this,r,u,a)}s.refCount+=1}catch(e){}return t.call(this,r,n,a)}}));t(n,"removeEventListener",(function(e){return function(t,r,n){if("click"===t||"keypress"==t)try{var a=this;var i=a.__sentry_instrumentation_handlers__||{};var o=i[t];if(o){o.refCount-=1;if(o.refCount<=0){e.call(this,t,o.handler,n);o.handler=void 0;delete i[t]}0===Object.keys(i).length&&delete a.__sentry_instrumentation_handlers__}}catch(e){}return e.call(this,t,r,n)}}))}}))}}let C=null;function instrumentError(){C=I.onerror;I.onerror=function(e,t,r,n,a){triggerHandlers("error",{column:n,error:a,line:r,msg:e,url:t});return!!C&&C.apply(this,arguments)}}let L=null;function instrumentUnhandledRejection(){L=I.onunhandledrejection;I.onunhandledrejection=function(e){triggerHandlers("unhandledrejection",e);return!L||L.apply(this,arguments)}}function memoBuilder(){var e="function"===typeof WeakSet;var t=e?new WeakSet:[];function memoize(r){if(e){if(t.has(r))return true;t.add(r);return false}for(let e=0;e<t.length;e++){var n=t[e];if(n===r)return true}t.push(r);return false}function unmemoize(r){if(e)t.delete(r);else for(let e=0;e<t.length;e++)if(t[e]===r){t.splice(e,1);break}}return[memoize,unmemoize]}
/**
 * Recursively normalizes the given object.
 *
 * - Creates a copy to prevent original input mutation
 * - Skips non-enumerable properties
 * - When stringifying, calls `toJSON` if implemented
 * - Removes circular references
 * - Translates non-serializable values (`undefined`/`NaN`/functions) to serializable format
 * - Translates known global objects/classes to a string representations
 * - Takes care of `Error` object serialization
 * - Optionally limits depth of final output
 * - Optionally limits number of properties/elements included in any single object/array
 *
 * @param input The object to be normalized.
 * @param depth The max depth to which to normalize the object. (Anything deeper stringified whole.)
 * @param maxProperties The max number of elements or properties to be included in any single array or
 * object in the normallized output..
 * @returns A normalized version of the object, or `"**non-serializable**"` if any errors are thrown during normalization.
 */function normalize(e,t=Infinity,r=Infinity){try{return visit("",e,t,r)}catch(e){return{ERROR:`**non-serializable** (${e})`}}}function normalizeToSize(e,t=3,r=102400){var n=normalize(e,t);return jsonSize(n)>r?normalizeToSize(e,t-1,r):n}
/**
 * Visits a node to perform normalization on it
 *
 * @param key The key corresponding to the given node
 * @param value The node to be visited
 * @param depth Optional number indicating the maximum recursion depth
 * @param maxProperties Optional maximum number of properties/elements included in any single object/array
 * @param memo Optional Memo class handling decycling
 */function visit(e,t,n=Infinity,a=Infinity,i=memoBuilder()){const[o,s]=i;if(null===t||["number","boolean","string"].includes(typeof t)&&!E(t))return t;var u=stringifyValue(e,t);if(!u.startsWith("[object "))return u;if(t.__sentry_skip_normalization__)return t;if(0===n)return u.replace("object ","");if(o(t))return"[Circular ~]";var c=t;if(c&&"function"===typeof c.toJSON)try{var l=c.toJSON();return visit("",l,n-1,a,i)}catch(e){}var f=Array.isArray(t)?[]:{};let d=0;var p=r(t);for(var m in p)if(Object.prototype.hasOwnProperty.call(p,m)){if(d>=a){f[m]="[MaxProperties ~]";break}var g=p[m];f[m]=visit(m,g,n-1,a,i);d+=1}s(t);return f}
/**
 * Stringify the given value. Handles various known special values and types.
 *
 * Not meant to be used on simple primitives which already have a string representation, as it will, for example, turn
 * the number 1231 into "[Object Number]", nor on `null`, as it will throw.
 *
 * @param value The value to stringify
 * @returns A stringified representation of the given value
 */function stringifyValue(e,t){try{return"domain"===e&&t&&"object"===typeof t&&t._events?"[Domain]":"domainEmitter"===e?"[DomainEmitter]":"undefined"!==typeof global&&t===global?"[Global]":"undefined"!==typeof window&&t===window?"[Window]":"undefined"!==typeof document&&t===document?"[Document]":S(t)?"[SyntheticEvent]":"number"===typeof t&&t!==t?"[NaN]":void 0===t?"[undefined]":"function"===typeof t?`[Function: ${getFunctionName(t)}]`:"symbol"===typeof t?`[${String(t)}]`:"bigint"===typeof t?`[BigInt: ${String(t)}]`:`[object ${Object.getPrototypeOf(t).constructor.name}]`}catch(e){return`**non-serializable** (${e})`}}function utf8Length(e){return~-encodeURI(e).split(/%..|./).length}function jsonSize(e){return utf8Length(JSON.stringify(e))}var M;(function(e){var t=0;e[e.PENDING=t]="PENDING";var r=1;e[e.RESOLVED=r]="RESOLVED";var n=2;e[e.REJECTED=n]="REJECTED"})(M||(M={}));
/**
 * Creates a resolved sync promise.
 *
 * @param value the value to resolve the promise with
 * @returns the resolved sync promise
 */function resolvedSyncPromise(e){return new SyncPromise((t=>{t(e)}))}
/**
 * Creates a rejected sync promise.
 *
 * @param value the value to reject the promise with
 * @returns the rejected sync promise
 */function rejectedSyncPromise(e){return new SyncPromise(((t,r)=>{r(e)}))}class SyncPromise{__init(){this._state=M.PENDING}__init2(){this._handlers=[]}constructor(e){SyncPromise.prototype.__init.call(this);SyncPromise.prototype.__init2.call(this);SyncPromise.prototype.__init3.call(this);SyncPromise.prototype.__init4.call(this);SyncPromise.prototype.__init5.call(this);SyncPromise.prototype.__init6.call(this);try{e(this._resolve,this._reject)}catch(e){this._reject(e)}}then(e,t){return new SyncPromise(((r,n)=>{this._handlers.push([false,t=>{if(e)try{r(e(t))}catch(e){n(e)}else r(t)},e=>{if(t)try{r(t(e))}catch(e){n(e)}else n(e)}]);this._executeHandlers()}))}catch(e){return this.then((e=>e),e)}finally(e){return new SyncPromise(((t,r)=>{let n;let a;return this.then((t=>{a=false;n=t;e&&e()}),(t=>{a=true;n=t;e&&e()})).then((()=>{a?r(n):t(n)}))}))}__init3(){this._resolve=e=>{this._setResult(M.RESOLVED,e)}}__init4(){this._reject=e=>{this._setResult(M.REJECTED,e)}}__init5(){this._setResult=(e,t)=>{if(this._state===M.PENDING)if(D(t))void t.then(this._resolve,this._reject);else{this._state=e;this._value=t;this._executeHandlers()}}}__init6(){this._executeHandlers=()=>{if(this._state!==M.PENDING){var e=this._handlers.slice();this._handlers=[];e.forEach((e=>{if(!e[0]){this._state===M.RESOLVED&&e[1](this._value);this._state===M.REJECTED&&e[2](this._value);e[0]=true}}))}}}}
/**
 * Creates an new PromiseBuffer object with the specified limit
 * @param limit max number of promises that can be stored in the buffer
 */function makePromiseBuffer(e){var t=[];function isReady(){return void 0===e||t.length<e}
/**
   * Remove a promise from the queue.
   *
   * @param task Can be any PromiseLike<T>
   * @returns Removed promise.
   */function remove(e){return t.splice(t.indexOf(e),1)[0]}
/**
   * Add a promise (representing an in-flight action) to the queue, and set it to remove itself on fulfillment.
   *
   * @param taskProducer A function producing any PromiseLike<T>; In previous versions this used to be `task:
   *        PromiseLike<T>`, but under that model, Promises were instantly created on the call-site and their executor
   *        functions therefore ran immediately. Thus, even if the buffer was full, the action still happened. By
   *        requiring the promise to be wrapped in a function, we can defer promise creation until after the buffer
   *        limit check.
   * @returns The original promise.
   */function add(e){if(!isReady())return rejectedSyncPromise(new SentryError("Not adding Promise due to buffer limit reached."));var r=e();-1===t.indexOf(r)&&t.push(r);void r.then((()=>remove(r))).then(null,(()=>remove(r).then(null,(()=>{}))));return r}
/**
   * Wait for all promises in the queue to resolve or for timeout to expire, whichever comes first.
   *
   * @param timeout The time, in ms, after which to resolve to `false` if the queue is still non-empty. Passing `0` (or
   * not passing anything) will make the promise wait as long as it takes for the queue to drain before resolving to
   * `true`.
   * @returns A promise which will resolve to `true` if the queue is already empty or drains before the timeout, and
   * `false` otherwise
   */function drain(e){return new SyncPromise(((r,n)=>{let a=t.length;if(!a)return r(true);var i=setTimeout((()=>{e&&e>0&&r(false)}),e);t.forEach((e=>{void resolvedSyncPromise(e).then((()=>{if(!--a){clearTimeout(i);r(true)}}),n)}))}))}return{$:t,add:add,drain:drain}}
/**
 * Parses string form of URL into an object
 * // borrowed from https://tools.ietf.org/html/rfc3986#appendix-B
 * // intentionally using regex and not <a/> href parsing trick because React Native and other
 * // environments where DOM might not be available
 * @returns parsed URL object
 */function parseUrl(e){if(!e)return{};var t=e.match(/^(([^:/?#]+):)?(\/\/([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$/);if(!t)return{};var r=t[6]||"";var n=t[8]||"";return{host:t[4],path:t[5],protocol:t[2],relative:t[5]+r+n}}
/**
 * Strip the query string and fragment off of a given URL or path (if present)
 *
 * @param urlPath Full URL or path, including possible query string and/or fragment
 * @returns URL or path without query string or fragment
 */function stripUrlQueryAndFragment(e){return e.split(/[\?#]/,1)[0]}function getNumberOfUrlSegments(e){return e.split(/\\?\//).filter((e=>e.length>0&&","!==e)).length}var q={ip:false,request:true,transaction:true,user:true};var z=["cookies","data","headers","method","query_string","url"];var G=["id","username","email"];function addRequestDataToTransaction(e,t,r){if(e){e.metadata.source&&"url"!==e.metadata.source||e.setName(...extractPathForTransaction(t,{path:true,method:true}));e.setData("url",t.originalUrl||t.url);t.baseUrl&&e.setData("baseUrl",t.baseUrl);e.setData("query",extractQueryParams(t,r))}}
/**
 * Extracts a complete and parameterized path from the request object and uses it to construct transaction name.
 * If the parameterized transaction name cannot be extracted, we fall back to the raw URL.
 *
 * Additionally, this function determines and returns the transaction name source
 *
 * eg. GET /mountpoint/user/:id
 *
 * @param req A request object
 * @param options What to include in the transaction name (method, path, or a custom route name to be
 *                used instead of the request's route)
 *
 * @returns A tuple of the fully constructed transaction name [0] and its source [1] (can be either 'route' or 'url')
 */function extractPathForTransaction(e,t={}){var r=e.method&&e.method.toUpperCase();let n="";let a="url";if(t.customRoute||e.route){n=t.customRoute||`${e.baseUrl||""}${e.route&&e.route.path}`;a="route"}else(e.originalUrl||e.url)&&(n=stripUrlQueryAndFragment(e.originalUrl||e.url||""));let i="";t.method&&r&&(i+=r);t.method&&t.path&&(i+=" ");t.path&&n&&(i+=n);return[i,a]}function extractTransaction(e,t){switch(t){case"path":return extractPathForTransaction(e,{path:true})[0];case"handler":return e.route&&e.route.stack&&e.route.stack[0]&&e.route.stack[0].name||"<anonymous>";case"methodPath":default:return extractPathForTransaction(e,{path:true,method:true})[0]}}function extractUserData(e,t){var r={};var n=Array.isArray(t)?t:G;n.forEach((t=>{e&&t in e&&(r[t]=e[t])}));return r}
/**
 * Normalize data from the request object, accounting for framework differences.
 *
 * @param req The request object from which to extract data
 * @param options.include An optional array of keys to include in the normalized data. Defaults to
 * DEFAULT_REQUEST_INCLUDES if not provided.
 * @param options.deps Injected, platform-specific dependencies
 * @returns An object containing normalized request data
 */function extractRequestData(e,t){const{include:r=z,deps:n}=t||{};var a={};var i=e.headers||{};var o=e.method;var s=e.hostname||e.host||i.host||"<no host>";var u="https"===e.protocol||e.socket&&e.socket.encrypted?"https":"http";var c=e.originalUrl||e.url||"";var l=`${u}://${s}${c}`;r.forEach((t=>{switch(t){case"headers":a.headers=i;break;case"method":a.method=o;break;case"url":a.url=l;break;case"cookies":a.cookies=e.cookies||i.cookie&&n&&n.cookie&&n.cookie.parse(i.cookie)||{};break;case"query_string":a.query_string=extractQueryParams(e,n);break;case"data":if("GET"===o||"HEAD"===o)break;void 0!==e.body&&(a.data=_(e.body)?e.body:JSON.stringify(normalize(e.body)));break;default:({}).hasOwnProperty.call(e,t)&&(a[t]=e[t])}}));return a}
/**
 * Add data from the given request to the given event
 *
 * @param event The event to which the request data will be added
 * @param req Request object
 * @param options.include Flags to control what data is included
 * @param options.deps Injected platform-specific dependencies
 * @hidden
 */function addRequestDataToEvent(e,t,r){var n={...q,...T([r,"optionalAccess",e=>e.include])};if(n.request){var a=Array.isArray(n.request)?extractRequestData(t,{include:n.request,deps:T([r,"optionalAccess",e=>e.deps])}):extractRequestData(t,{deps:T([r,"optionalAccess",e=>e.deps])});e.request={...e.request,...a}}if(n.user){var i=t.user&&w(t.user)?extractUserData(t.user,n.user):{};Object.keys(i).length&&(e.user={...e.user,...i})}if(n.ip){var o=t.ip||t.socket&&t.socket.remoteAddress;o&&(e.user={...e.user,ip_address:o})}n.transaction&&!e.transaction&&(e.transaction=extractTransaction(t,n.transaction));return e}function extractQueryParams(e,t){let r=e.originalUrl||e.url||"";if(r){r.startsWith("/")&&(r=`http://dogs.are.great${r}`);return e.query||void 0!==typeof URL&&new URL(r).search.replace("?","")||t&&t.url&&t.url.parse(r).query||void 0}}var V=["fatal","error","warning","log","info","debug"];
/**
 * Converts a string-based level into a member of the deprecated {@link Severity} enum.
 *
 * @deprecated `severityFromString` is deprecated. Please use `severityLevelFromString` instead.
 *
 * @param level String representation of Severity
 * @returns Severity
 */function severityFromString(e){return severityLevelFromString(e)}
/**
 * Converts a string-based level into a `SeverityLevel`, normalizing it along the way.
 *
 * @param level String representation of desired `SeverityLevel`.
 * @returns The `SeverityLevel` corresponding to the given string, or 'log' if the string isn't a valid level.
 */function severityLevelFromString(e){return"warn"===e?"warning":V.includes(e)?e:"log"}var J={nowSeconds:()=>Date.now()/1e3};function getBrowserPerformance(){const{performance:e}=s();if(e&&e.now){var t=Date.now()-e.now();return{now:()=>e.now(),timeOrigin:t}}}function getNodePerformance(){try{var e=p(module,"perf_hooks");return e.performance}catch(e){return}}var W=v()?getNodePerformance():getBrowserPerformance();var Y=void 0===W?J:{nowSeconds:()=>(W.timeOrigin+W.now())/1e3};var K=J.nowSeconds.bind(J);var Q=Y.nowSeconds.bind(Y);var X=Q;var Z=void 0!==W;let ee;var te=(()=>{const{performance:e}=s();if(e&&e.now){var t=36e5;var r=e.now();var n=Date.now();var a=e.timeOrigin?Math.abs(e.timeOrigin+r-n):t;var i=a<t;var o=e.timing&&e.timing.navigationStart;var u="number"===typeof o;var c=u?Math.abs(o+r-n):t;var l=c<t;if(i||l){if(a<=c){ee="timeOrigin";return e.timeOrigin}ee="navigationStart";return o}ee="dateNow";return n}ee="none"})();var re=new RegExp("^[ \\t]*([0-9a-f]{32})?-?([0-9a-f]{16})?-?([01])?[ \\t]*$");
/**
 * Extract transaction context data from a `sentry-trace` header.
 *
 * @param traceparent Traceparent string
 *
 * @returns Object containing data from the header, or undefined if traceparent string is malformed
 */function extractTraceparentData(e){var t=e.match(re);if(t){let e;"1"===t[3]?e=true:"0"===t[3]&&(e=false);return{traceId:t[1],parentSampled:e,parentSpanId:t[2]}}}function createEnvelope(e,t=[]){return[e,t]}function addItemToEnvelope(e,t){const[r,n]=e;return[r,[...n,t]]}function forEachEnvelopeItem(e,t){var r=e[1];r.forEach((e=>{var r=e[0].type;t(e,r)}))}function encodeUTF8(e,t){var r=t||new TextEncoder;return r.encode(e)}function serializeEnvelope(e,t){const[r,n]=e;let a=JSON.stringify(r);function append(e){"string"===typeof a?a="string"===typeof e?a+e:[encodeUTF8(a,t),e]:a.push("string"===typeof e?encodeUTF8(e,t):e)}for(var i of n){const[e,t]=i;append(`\n${JSON.stringify(e)}\n`);append("string"===typeof t||t instanceof Uint8Array?t:JSON.stringify(t))}return"string"===typeof a?a:concatBuffers(a)}function concatBuffers(e){var t=e.reduce(((e,t)=>e+t.length),0);var r=new Uint8Array(t);let n=0;for(var a of e){r.set(a,n);n+=a.length}return r}function createAttachmentEnvelopeItem(e,t){var r="string"===typeof e.data?encodeUTF8(e.data,t):e.data;return[n({type:"attachment",length:r.length,filename:e.filename,content_type:e.contentType,attachment_type:e.attachmentType}),r]}var ne={session:"session",sessions:"session",attachment:"attachment",transaction:"transaction",event:"error",client_report:"internal",user_report:"default"};function envelopeItemTypeToDataCategory(e){return ne[e]}
/**
 * Creates client report envelope
 * @param discarded_events An array of discard events
 * @param dsn A DSN that can be set on the header. Optional.
 */function createClientReportEnvelope(e,t,r){var n=[{type:"client_report"},{timestamp:r||K(),discarded_events:e}];return createEnvelope(t?{dsn:t}:{},[n])}var ae=6e4;
/**
 * Extracts Retry-After value from the request header or returns default value
 * @param header string representation of 'Retry-After' header
 * @param now current unix timestamp
 *
 */function parseRetryAfterHeader(e,t=Date.now()){var r=parseInt(`${e}`,10);if(!isNaN(r))return 1e3*r;var n=Date.parse(`${e}`);return isNaN(n)?ae:n-t}function disabledUntil(e,t){return e[t]||e.all||0}function isRateLimited(e,t,r=Date.now()){return disabledUntil(e,t)>r}function updateRateLimits(e,{statusCode:t,headers:r},n=Date.now()){var a={...e};var i=r&&r["x-sentry-rate-limits"];var o=r&&r["retry-after"];if(i)for(var s of i.trim().split(",")){const[e,t]=s.split(":",2);var u=parseInt(e,10);var c=1e3*(isNaN(u)?60:u);if(t)for(var l of t.split(";"))a[l]=n+c;else a.all=n+c}else o?a.all=n+parseRetryAfterHeader(o,n):429===t&&(a.all=n+6e4);return a}var ie="baggage";var oe="sentry-";var se=/^sentry-/;var ue=8192;function createBaggage(e,t="",r=true){return[{...e},t,r]}function getBaggageValue(e,t){return e[0][t]}function setBaggageValue(e,t,r){isBaggageMutable(e)&&(e[0][t]=r)}function isSentryBaggageEmpty(e){return 0===Object.keys(e[0]).length}function getSentryBaggageItems(e){return e[0]}
/**
 * Returns 3rd party baggage string of @param baggage
 * @param baggage
 */function getThirdPartyBaggage(e){return e[1]}
/**
 * Checks if baggage is mutable
 * @param baggage
 * @returns true if baggage is mutable, else false
 */function isBaggageMutable(e){return e[2]}
/**
 * Sets the passed baggage immutable
 * @param baggage
 */function setBaggageImmutable(e){e[2]=false}function serializeBaggage(e){return Object.keys(e[0]).reduce(((t,r)=>{var n=e[0][r];var a=`${oe}${encodeURIComponent(r)}=${encodeURIComponent(n)}`;var i=""===t?a:`${t},${a}`;if(i.length>ue){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&R.warn(`Not adding key: ${r} with val: ${n} to baggage due to exceeding baggage size limits.`);return t}return i}),e[1])}
/**
 * Parse a baggage header from a string or a string array and return a Baggage object
 *
 * If @param includeThirdPartyEntries is set to true, third party baggage entries are added to the Baggage object
 * (This is necessary for merging potentially pre-existing baggage headers in outgoing requests with
 * our `sentry-` values)
 */function parseBaggageHeader(e,t=false){if(!Array.isArray(e)&&!_(e)||"number"===typeof e){("undefined"===typeof __SENTRY_DEBUG__||__SENTRY_DEBUG__)&&R.warn("[parseBaggageHeader] Received input value of incompatible type: ",typeof e,e);return createBaggage({},"")}var r=(_(e)?e:e.join(",")).split(",").map((e=>e.trim())).filter((e=>""!==e&&(t||se.test(e))));return r.reduce((([e,t],r)=>{const[n,a]=r.split("=");if(se.test(n)){var i=decodeURIComponent(n.split("-")[1]);return[{...e,[i]:decodeURIComponent(a)},t,true]}return[e,""===t?r:`${t},${r}`,true]}),[{},"",true])}
/**
 * Merges the baggage header we saved from the incoming request (or meta tag) with
 * a possibly created or modified baggage header by a third party that's been added
 * to the outgoing request header.
 *
 * In case @param headerBaggageString exists, we can safely add the the 3rd party part of @param headerBaggage
 * with our @param incomingBaggage. This is possible because if we modified anything beforehand,
 * it would only affect parts of the sentry baggage (@see Baggage interface).
 *
 * @param incomingBaggage the baggage header of the incoming request that might contain sentry entries
 * @param thirdPartyBaggageHeader possibly existing baggage header string or string[] added from a third
 *        party to the request headers
 *
 * @return a merged and serialized baggage string to be propagated with the outgoing request
 */function mergeAndSerializeBaggage(e,t){if(!e&&!t)return"";var r=t&&parseBaggageHeader(t,true)||void 0;var n=r&&getThirdPartyBaggage(r);var a=createBaggage(e&&e[0]||{},n||"");return serializeBaggage(a)}
/**
 * Helper function that takes a raw baggage string (if available) and the processed sentry-trace header
 * data (if available), parses the baggage string and creates a Baggage object
 * If there is no baggage string, it will create an empty Baggage object.
 * In a second step, this functions determines if the created Baggage object should be set immutable
 * to prevent mutation of the Sentry data.
 *
 * Extracted this logic to a function because it's duplicated in a lot of places.
 *
 * @param rawBaggageValue
 * @param sentryTraceHeader
 */function parseBaggageSetMutability(e,t){var r=parseBaggageHeader(e||"");(t||!isSentryBaggageEmpty(r))&&setBaggageImmutable(r);return r}export{ie as BAGGAGE_HEADER_NAME,ae as DEFAULT_RETRY_AFTER,ue as MAX_BAGGAGE_STRING_LENGTH,oe as SENTRY_BAGGAGE_KEY_PREFIX,se as SENTRY_BAGGAGE_KEY_PREFIX_REGEX,SentryError,SyncPromise,re as TRACEPARENT_REGEXP,ee as _browserPerformanceTimeOriginMode,addInstrumentationHandler,addItemToEnvelope,addRequestDataToEvent,addRequestDataToTransaction,te as browserPerformanceTimeOrigin,createAttachmentEnvelopeItem,createBaggage,createClientReportEnvelope,createEnvelope,createStackParser,K as dateTimestampInSeconds,disabledUntil,dsnFromString,dsnToString,envelopeItemTypeToDataCategory,extractPathForTransaction,extractRequestData,extractTraceparentData,forEachEnvelopeItem,getBaggageValue,getFunctionName,getNumberOfUrlSegments,getSentryBaggageItems,getThirdPartyBaggage,isBaggageMutable,isRateLimited,isSentryBaggageEmpty,makeDsn,makePromiseBuffer,memoBuilder,mergeAndSerializeBaggage,nodeStackLineParser,normalize,normalizeToSize,parseBaggageHeader,parseBaggageSetMutability,parseRetryAfterHeader,parseUrl,rejectedSyncPromise,resolvedSyncPromise,serializeBaggage,serializeEnvelope,setBaggageImmutable,setBaggageValue,severityFromString,severityLevelFromString,stackParserFromStackParserOptions,stripSentryFramesAndReverse,stripUrlQueryAndFragment,Q as timestampInSeconds,X as timestampWithMs,updateRateLimits,Z as usingPerformanceAPI,V as validSeverityLevels,visit as walk};


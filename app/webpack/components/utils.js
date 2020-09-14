// helper for enabling IE 8 event bindings
const addEvent = (el, type, handler) => {
  if (el.attachEvent) el.attachEvent('on' + type, handler);
  else el.addEventListener(type, handler);
};

// live binding helper with CSS selector
export const live = (selector, event, callback, context) => {
  addEvent(context || document, event, function(e) {
    const qs = (context || document).querySelectorAll(selector);
    if (qs) {
      let el = e.target || e.srcElement,
        index = -1;
      while (el && (index = Array.prototype.indexOf.call(qs, el)) === -1) el = el.parentElement;
      if (index > -1) callback.call(el, e);
    }
  });
};

export const prop = (selector, attrName, enabled) => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    enabled ? el.setAttribute(attrName, attrName) : el.removeAttribute(attrName);
  }
};

export const checked = (selector, value) => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    el.checked = value;
  }
};

export const addClass = (selector, className) => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    el.classList.add(className);
  }
};

export const removeClass = (selector, className) => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    el.classList.remove(className);
  }
};

export const show = selector => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    el.style.display = 'block';
  }
};

export const hide = selector => {
  const els = document.querySelectorAll(selector);
  for (const el of els) {
    el.style.display = 'none';
  }
};

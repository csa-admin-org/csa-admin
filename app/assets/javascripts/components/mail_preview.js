$(document).on('turbolinks:load', function() {
  $('iframe.mail_preview').on('load', function() {
    var iframes = document.querySelectorAll('iframe.mail_preview');
    iframes = Array.from(iframes)
    var heights = iframes.map(i => i.contentWindow.document.body.offsetHeight)
    this.style.height = Math.max(...heights) + 'px';
  });
});

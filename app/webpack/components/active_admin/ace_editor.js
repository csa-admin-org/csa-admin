import 'ace-builds';
import 'ace-builds/src-noconflict/mode-liquid'
import 'ace-builds/src-noconflict/mode-yaml'
import 'ace-builds/src-noconflict/theme-dreamweaver'

$(document).on('turbolinks:load', function() {
  $('textarea.ace-editor').each(function() {
    var textarea = $(this);
    var editDiv = $('<div>').insertBefore(textarea);
    textarea.css('display', 'none');
    var editor = ace.edit(editDiv[0], {
      mode: 'ace/mode/' + this.dataset.mode,
      theme: 'ace/theme/dreamweaver',
      highlightActiveLine: false,
      showGutter: false,
      printMargin: false,
      useSoftTabs: true,
      tabSize: 2,
      wrapBehavioursEnabled: true,
      wrap: true,
      minLines: 10,
      maxLines: 30,
      fontSize: 14
    });

    editor.getSession().setValue(textarea.val());
    textarea.closest('form').submit(function() {
      textarea.val(editor.getSession().getValue());
    })
  });
});

import { EmojiButton } from '@joeattardi/emoji-button';
import deEmojiData from '@roderickhsiao/emoji-button-locale-data/dist/de';
import frEmojiData from '@roderickhsiao/emoji-button-locale-data/dist/fr';
import itEmojiData from '@roderickhsiao/emoji-button-locale-data/dist/it';

$(document).on('turbolinks:load', function() {
  const trigger = document.querySelector('.emoji-button');
  if (trigger) {
    const locale = document.documentElement.lang
    var localeEmojiData;
    if (locale === 'de') {
      localeEmojiData = deEmojiData;
    } else if (locale === 'fr') {
      localeEmojiData =  frEmojiData;
    } else if (locale === 'it') {
      localeEmojiData = itEmojiData;
    };
    const picker = new EmojiButton({
      showRecents: false,
      position: 'bottom-start',
      emojiData: localeEmojiData
    });


    picker.on('emoji', selection => {
      trigger.value = selection.emoji;
    });
    trigger.addEventListener('click', () => {
      picker.togglePicker(trigger);
    });
  }
});

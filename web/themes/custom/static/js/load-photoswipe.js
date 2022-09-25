/* SPDX-License-Identifier: MIT
 * Copyright (c) 2017 Li-Wen Yip */

$( document ).ready(function() {
  var items = [];

  $('figure').each( function() {
    var $figure = $(this);
    var $a = $figure.find('a');
    var $img = $figure.find('img');
    var $figcaption = $figure.find('figcaption')[0];

    var $src = $a.attr('href');
    var $title = $figcaption.innerHTML;
    var $msrc = $img.attr('src');

    if ($a.data('size')) {
      var $size = $a.data('size').split('x');
      var item = {
        src: $src,
        w: $size[0],
        h: $size[1],
        title: $title,
        msrc: $msrc
      };
    } else {
      var item = {
        src: $src,
        w: 580,
        h: 580,
        title: $title,
        msrc: $msrc
      };
      var img = new Image();
      img.src = $src;
      var wait = setInterval(function() {
        var w = img.naturalWidth,
          h = img.naturalHeight;
        if (w && h) {
          clearInterval(wait);
          item.w = w;
          item.h = h;
        }
      }, 30);
    }

    var index = items.length;
    items.push(item);

    $figure.on('click', function(event) {
      event.preventDefault();
      var $pswp = $('.pswp')[0];
      var options = {
        index: index,
        bgOpacity: 0.8,
        showHideOpacity: true
      }
      new PhotoSwipe($pswp, PhotoSwipeUI_Default, items, options).init();
    });
  });
});

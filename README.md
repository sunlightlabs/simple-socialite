# Simple Socialite
A silently failing, HTML tag-based abstraction API for [dbushell/socialite](https://github.com/dbushell/socialite)

---

## Getting started

Build your own and post assets to a server:

    $ cp settings.coffee.example settings.coffee
    $ npm install

    # twitter, facebook and google plus are baked in to socialite
    $ cake --extensions 'hackernews github whatever...' build

Implement all your widgets via a single tag:

    <html>
        <head>
            <title>Test title for social buttons</title>
            <meta name="description" content="My description">
            <script src="path/to/jquery.min.js"></script>
            <script src="path/to/simple-socialite-pack.min.js"></script>
        </head>
        <body>
            <div class="share-buttons" data-socialite="auto" data-services="facebook-like,twitter-share,googleplus-one"></div>
        </body>
    </html>

## Adding extensions

You can compile in other extensions by adding them to `bower.json`. Any files matching the glob `bower_components/**/extensions/socialite.*.js` will be eligible to be rolled into the build.

Then build, including the new extensions by name:

    cake --extensions 'tumblr-simple facebook-share' build

Then add them to data-services:

    <div class="share-buttons" data-socialite="auto" data-services="facebook tumblr"></div>

## Customizing options

Options are set by data-attrs. The 'Share Bar' takes options as top-level data attributes:

    <div class="share-buttons"
         data-socialite="auto"
         data-layout="vertical"
         data-services="twitter-share"></div>

Global options for all buttons are set via setting `data-options` with a querystring:

    <div class="share-buttons"
         data-socialite="auto"
         data-layout="vertical"
         data-services="twitter-share"
         data-options="title=my%20custom%20title&amp;url=http%3A%2F%2Fmy.custom.url%2F"></div>

Per-service options are set with a `data-{service}-options` attr, which will override global options:

    <div class="share-buttons"
         data-socialite="auto"
         data-layout="vertical"
         data-services="twitter-share"
         data-twitter-share-options="defaultText=my%20custom%20text%20just%20for%20twitter"></div>

Which options are supported will vary from widget to widget, but all of them (that don't use page parsing and open graph tags) will respond to `title` and `url`

## The Events API

Simple-socialite `ShareBar`s respond to jQuery events to control when they are rendered. To create buttons at another time than domready, change `data-socialite` to the event name you'd like to send:

    <div class="share-buttons" data-socialite="socialbuttons" data-services="facebook tumblr"></div>

To render, send the event 'socialbuttons':

    $('share-buttons').trigger('socialbuttons');

If your page uses pushState, you can alter the data-attrs of the container and use the events API to re-render the buttons with the new options:

    $('share-buttons').eq(0)
      .attr('data-options', 'title=' + encodeURIComponent('my new title that didn\'t trigger a page reload'))
      .trigger('socialbuttons');

## Elements created after DOMReady

You can also use simple-socialite to render buttons that weren't available at bootstrap time, by sending any wrapper elements the 'register.simplesocialite' event:

    $('<div></div>')
      .addClass('share-buttons')
      .attr('data-socialite', 'auto')
      .attr('data-services', 'facebook-like,twitter-share')
      .appendTo('body')
      .trigger('register');

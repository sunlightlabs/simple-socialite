###
Simple-Socialite
----------------

A silently failing, HTML tag-based abstraction API for socialite.js

Usage:
<div class="share-buttons" data-socialite="auto" data-services="twitter, facebook"></div>
###

tries = 0
check = =>
  if not jQuery?
    if tries < 6000
      tries++
      setTimeout(check, 10)
    else
      console? && console.log('Gave up trying to render your social buttons. Make sure jQuery is getting on the page at some point.')
  else

    $ = jQuery
    DEBUG = ("{% settings.DEBUG %}".toLowerCase() == "true") or false
    debug = (msgs...) ->
      DEBUG && console? && console.log(msgs...)

    ###
    Tiny plugin to return a nested object of all data-foo options on an element
    ###
    $.fn.getDataOptions = ->
      opts = {}
      el = $(this)[0]
      $.each el.attributes, (i, att) =>
        return true unless att.nodeName.match /^data-/ # jQuery hates 'continue'
        qs = att.nodeValue
        key = att.nodeName.replace(/^data-/, '')
        if key.match(/options$/)
          opts[key] = $.optionsFromQueryString qs
        else
          opts[key] = qs
      opts

    $.optionsFromQueryString = (qs) ->
      opts = {}
      parts = qs.split /(?:&(?:amp;)?|=)/
      $.each parts, (i, part) =>
        if i % 2
          opts[parts[i - 1]] = decodeURIComponent part
      debug opts
      opts

    # Implement underscore's html escape because jquery text() isn't cutting it
    htmlEscapes =
      '&': '&amp;'
      '<': '&lt;'
      '>': '&gt;'
      '"': '&quot;'
      "'": '&#x27;'
      '/': '&#x2F;'
    htmlEscaper = /[&<>"'\/]/g;
    $.safeString = (s) ->
      ('' + s).replace(htmlEscaper, (match) ->
        htmlEscapes[match])

    ###
    Individual share button class
    Takes a string @provider and object @options
    ###
    class ShareButton
      constructor: (@provider, @options) ->
        #pass

      to_html_params: ->
        opts = ''
        @options = new OptionMapper(@provider, @options).translate()
        $.each @options, (key, val) =>
          escaped_val = $.safeString val
          opts += "data-#{key}=\"#{escaped_val}\" "
        opts.replace(/\ $/, '')

      provider_display: ->
        custom =
          "twitter-share": "Twitter"
          "facebook-like": "Facebook"
          "pinterest-pinit": "Pinterest"
          "googleplus-one": "Google Plus"

        custom[@provider] or ( =>
          name = @provider.replace /-simple$/, ''
          parts = name.split(' ')
          $.each parts, (i, part) ->
            parts[i] = part.charAt(0).toUpperCase() + part.slice(1)
          parts.join(' '))()

      render: ->
        "<a href='' class='socialite #{@provider}' #{@to_html_params()}>Share on #{@provider_display()}</a>"


    ###
    Share bar class
    Takes a DOM or jQuery element @wrapper, such as:
    new ShareBar $('<div class="share-buttons" data-socialite="auto" data-services="facebook,twitter"></div>')
    ###
    class ShareBar
      constructor: (@wrapper) ->
        @wrapper = $ @wrapper
        @options = $.extend {}, @defaults(), $(@wrapper).getDataOptions()
        @buttons = []
        $.each @options.services.split(/, ?/), (i, service) =>
          resolvedService = @serviceMappings()[service] or service
          @buttons.push(new ShareButton(resolvedService, $.extend({},
                                        @services()[resolvedService],
                                        @options.options,
                                        @options["#{resolvedService}-options"]
                                        @options["#{service}-options"])))

      container: ->
        $ "<table style='vertical-align:middle;'><tbody></tbody></table>"

      defaults: ->
        layout: 'horizontal'  # vertical
        shortURLs: 'never'  # always, whenRequired
        showTooltips: false  # true

      services: ->
        "twitter-simple": {}
        "twitter-share": {}
        "twitter-follow": {}
        "twitter-mention": {}
        "twitter-hashtag": {}
        "twitter-embed": {}
        "facebook-like": {}
        "facebook-share": {}
        "googleplus-simple": {}
        "googleplus-one": {}
        "linkedin-share": {}
        "linkedin-simple": {}
        "linkedin-recommend": {}
        "pinterest-pinit": {}
        "spotify-play": {}
        "hackernews-share": {}
        "github-watch": {}
        "github-fork": {}
        "github-follow": {}
        "tumblr-simple": {}
        "email-simple": {}

      serviceMappings: ->
        "twitter": "twitter-simple"
        "twitter-tweet": "twitter-share"
        "facebook": "facebook-share"
        "googleplus": "googleplus-simple"
        "google-plusone": "googleplus-one"
        "linkedin": "linkedin-simple"
        "pinterest": "pinterest-pinit"
        "tumblr": "tumblr-simple"
        "email": "email-simple"

      render: ->
        @rendered = @container()
        cursor = @rendered.find('tbody')
        cursor = @rendered.append('<tr></tr>').find('tr') if @options.layout is 'horizontal'
        $.each @buttons, (i, button) =>
          btn = $ "<td>#{button.render()}</td>"
          btn = btn.wrap('<tr></tr>').parents('tr') if @options.layout is 'vertical'
          cursor.append btn

        @wrapper.empty().append(@rendered)
        debug "loading contents of #{@wrapper}"
        Socialite.load(@wrapper[0])


    ###
    Option mapper class
    Normalizes a set of options to a given service's specific params
    ###

    class OptionMapper
      constructor: (@provider, @options) ->
        @translations =
          "twitter-share": =>
            unless @options['size']
              (@options['size'] = @options['width']) and delete @options['width']
            unless @options['text']
              (@options['text'] = @options['defaultText']) and delete @options['defaultText']
            unless @options['text']
              (@options['text'] = @options['title']) and delete @options['title']
            if @options['lang']
              @options['lang'] = @options['lang'].replace(/-.+$/, '')
            @options

          "twitter-simple": =>
            @translations["twitter-share"]()

          "facebook-like": =>
            unless @options['href']
              (@options['href'] = @options['url']) and delete @options['url']
            unless @options['layout']
              if @options['showCounts'] is 'right'
                @options['layout'] = 'button_count'
            if @options['lang']
              @options['lang'] = @options['lang'].replace('-', '_')
            @options

          "googleplus-one": =>
            if not @options['showCounts'] and not @options['annotation']
              @options['annotation'] = 'none'
            if @options['showCounts'] and not @options['annotation']
              if @options['showCounts'] in ['right', 'top']
                delete @options['annotation']
                if @options['showCounts'] is 'top'
                  @options['size'] = 'tall'
            if @options['size'] is 24 or (@options['size'] is 16 and @options['showCounts'] is 'right')
              delete @options['size']
            if @options['size'] is 16
              @options['size'] = 'small'
            unless @options['href']
              (@options['href'] = @options['url']) and delete @options['url']
            @options

          "googleplus-share": =>
            if not @options['showCounts'] and not @options['annotation']
              @options['annotation'] = 'none'
            unless @options['annotation']
              if @options['showCounts'] is 'right'
                @options['annotation'] = 'bubble'
              if @options['showCounts'] is 'top'
                @options['annotation'] = 'vertical-bubble'
            if @options['size'] is 16
              delete @options['size']
            if @options['size'] is 24
              @options['height'] = 24
              delete @options['size']
            unless @options['href']
              (@options['href'] = @options['url']) and delete @options['url']
            @options

          "linkedin-share": =>
            if @options['showCounts'] and not @options['counter']
              (@options['counter'] = @options['showCounts']) and delete @options['showCounts']

        window.optionMapper = this

      provider_icon_name: ->
        {
        "facebook-share": "facebook"
        "googleplus-one": "googleplus"
        }[@provider] or @provider.replace(/-simple$/, '')

      button_img: ->
        "{% settings.ICON_BASE_URL %}/#{@options['size']}/#{@provider_icon_name()}.png"

      translate: ->
        # Handle generic options first
        if not @options['size']?
          @options['size'] = 16
        if typeof @options['size'] is 'string' and not isNaN(parseInt(@options['size'], 10))
          @options['size'] = parseInt(@options['size'], 10)
        if typeof @options['size'] is 'number'
          @options['size'] = if @options.size in [16, 24] then @options.size else 16
        unless @options['url']
          (@options['url'] = @options['linkBack']) and delete @options['linkBack'] if @options['linkBack']?
        unless @options['url']
          @options['url'] = $('meta[property="og:url"]').attr('content') or location.href
        unless @options['title']
          @options['title'] = $('meta[property="og:title"]').attr('content') or document.title
        if not @options['image']
          @options['image'] = @button_img()
        # unset showCounts=none if anyone did it
        if @options['showCounts'] in ['none', 'false', 'never']
          delete @options['showCounts']
        # set the default lang
        if not @options['lang']
          @options['lang'] = "{% settings.DEFAULT_LANG %}"

        # Then service-specific ones
        try
          @translations[@provider]()
        catch e
          debug "Totally failed to resolve options: #{e}. Falling back to defaults"
          @options

        @options


    ###
    Main bootstrap on dom ready
    ###
    $ ->
      debug "running onready bootstrap"
      selector = '.share-buttons[data-socialite], .share-buttons[data-gigya]'
      initShareBar = (el) ->
        try
          $(el).data 'sharebar', new ShareBar(el)
          $(el).data 'sharebar'
        catch e
          debug "Caught error initializing sharebar: #{e}"

      register = (el) ->
        el = $(el)
        trigger = el.attr('data-gigya') or $(el).attr('data-socialite')
        try
          el.on(trigger, =>
            initShareBar(el[0]).render())
        catch e
          el.bind(trigger, =>
            initShareBar(el[0]).render())
        el.trigger('auto');

      try
        $('body').on('register.simplesocialite', selector, ->
          register this
        )
      catch e
        $('body').delegate('register.simplesocialite', selector, ->
          register this
        )

      $(selector).each ->
        el = this
        trigger = $(el).attr('data-gigya') or $(el).attr('data-socialite')
        register el

###
Kick off the jQuery check
###
check()

###
Simple-Socialite
----------------

A silently failing, HTML tag-based abstraction API for socialite.js

Usage:
<div class="share-buttons" data-socialite="auto" data-services="twitter, facebook"></div>
###

###
Global object for classes
###
window.SimpleSocialite ?= {}

###
check() ensures all dependencies are loaded
before defining any classes that reference them.
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
      @_customNames ?=
        "twitter-share": "Twitter"
        "facebook-like": "Facebook"
        "pinterest-pinit": "Pinterest"
        "googleplus-one": "Google Plus"

      @customNames: ->
        @_customNames

      @registerCustomName: (name, displayName) ->
        if @customNames()[name]?
          throw "Custom name #{name} is already registered."
        @_customNames[name] = displayName

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
        @constructor.customNames()[@provider] or ( =>
          name = @provider.replace /-simple$/, ''
          parts = name.split(' ')
          $.each parts, (i, part) ->
            parts[i] = part.charAt(0).toUpperCase() + part.slice(1)
          parts.join(' '))()

      render: ->
        "<a href='' class='socialite #{@provider}' #{@to_html_params()}>Share on #{@provider_display()}</a>"

    window.SimpleSocialite.ShareButton = ShareButton

    ###
    Share bar class
    Takes a DOM or jQuery element @wrapper, such as:
    new ShareBar $('<div class="share-buttons" data-socialite="auto" data-services="facebook,twitter"></div>')
    ###
    class ShareBar
      @_container = $ "<table style='vertical-align:middle;'><tbody></tbody></table>"

      @_defaults =
        layout: 'horizontal'  # vertical
        shortURLs: 'never'  # always, whenRequired
        showTooltips: false  # true

      @_services =
        "twitter-simple": {}
        "twitter-share": {}
        "twitter-follow": {}
        "twitter-mention": {}
        "twitter-hashtag": {}
        "twitter-embed": {}
        "facebook-like": {}
        "facebook-simple": {}
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

      @_serviceMappings =
        "twitter": "twitter-simple"
        "twitter-tweet": "twitter-share"
        "facebook": "facebook-simple"
        "googleplus": "googleplus-simple"
        "google-plusone": "googleplus-one"
        "linkedin": "linkedin-simple"
        "pinterest": "pinterest-pinit"
        "tumblr": "tumblr-simple"
        "email": "email-simple"

      @container: ->
        @_container.clone()

      @setContainer: (str) ->
        @_container = $ str

      @defaults: ->
        @_defaults


      @setDefault: (key, val) ->
        @_defaults ?= @defaults()
        @_defaults[key] = val
        @_defaults

      @services: ->
        @_services

      @serviceMappings: ->
        @_serviceMappings

      @registerButton: (opts) ->
        name = opts.name
        nickname = opts.nickname
        defaults = opts.defaults or {}
        if opts.displayName?
          displayName = opts.displayName
        if not opts.name?
          throw 'You must provide a name to register.'
        if @services()[name]? or @serviceMappings()[nickname]?
          throw "Name #{name} is already registered."
        if @serviceMappings()[nickname]?
          throw "Nickname #{nickname} is already registered."
        @_services[name] = defaults
        @_serviceMappings[nickname] = name
        if displayName?
          ShareButton.registerCustomName(name, displayName)

      constructor: (@wrapper) ->
        @wrapper = $ @wrapper
        @options = $.extend {}, @constructor.defaults(), $(@wrapper).getDataOptions()
        @buttons = []
        $.each @options.services.split(/, ?/), (i, service) =>
          resolvedService = @constructor.serviceMappings()[service] or service
          @buttons.push(new ShareButton(resolvedService, $.extend({},
                                        @constructor.services()[resolvedService],
                                        @options.options,
                                        @options["#{resolvedService}-options"]
                                        @options["#{service}-options"])))

      render: ->
        @rendered = @constructor.container()
        cursor = @rendered.find('tbody')
        cursor = cursor.append('<tr></tr>').find('tr') if @options.layout is 'horizontal'
        $.each @buttons, (i, button) =>
          btn = $ "<td>#{button.render()}</td>"
          btn = btn.wrap('<tr></tr>').parents('tr') if @options.layout is 'vertical'
          cursor.append btn

        @wrapper.empty().append(@rendered)
        debug "loading contents of #{@wrapper}"
        Socialite.load(@wrapper[0])

    window.SimpleSocialite.ShareBar ?= ShareBar

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
        "facebook-simple": "facebook"
        "googleplus-one": "googleplus"
        "googleplus-simple": "google-plus"
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
        # unless @options['image']
        #   @options['image'] = @button_img()
        unless @options['icon'] or @options['image']
          @options['icon'] = "sficon-#{@provider_icon_name()}"
        (@options['sficon'] = @options['icon']) and delete @options['icon'] if @options['icon']?
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
        $('body').delegate(selector, 'register.simplesocialite', ->
          register this
        )

      $(selector).each ->
        register this

      ###
      Set up GA tracking for the basic social networks and for clicks
      that bubble through `.socialite-instance`s, if _gaq is present
      ###
      if window._gaq?
        # facebook
        initFB = () ->
          FB.Event.subscribe 'edge.create', (url) ->
            debug 'tracking facebook'
            _gaq.push(['_trackSocial', 'facebook', 'like', url])
          FB.Event.subscribe 'edge.remove', (url) ->
            _gaq.push(['_trackSocial', 'facebook', 'unlike', url])
        window._fbAsyncInit = window.fbAsyncInit
        window.fbAsyncInit = () ->
          if typeof window._fbAsyncInit == 'function'
            window._fbAsyncInit()
          initFB()
        if window.FB?
          initFB()

        # twitter
        if window.twttr?
          trackTwitter = (evt) ->
            debug 'tracking twitter'
            try
              path = if (evt && evt.target && evt.target.nodeName == 'IFRAME') then $.optionsFromQueryString(evt.target.src.split('?')[1]).url else null
            catch e
              path = null
            _gaq.push(['_trackSocial', 'twitter', 'tweet', (path || location.href)])

          twttr.ready((twttr) ->
            twttr.events.bind('tweet', trackTwitter)
          )

        # basic
        trackBasic = (evt) ->
          if $(evt.target).hasClass('.socialite-instance')
            el = $(evt.target)
          else
            el = $(evt.target).parents('.socialite-instance').eq(0)
          button = el.attr('class').split(' ')[1]
          # trackTwitter() will catch 'simple' button tweets using intents, so skip them here.
          return if button.match(/twitter/) and window.twttr?
          debug "tracking #{button}"
          _gaq.push(['_trackSocial', button, 'share', location.href])
        ($().on? && $('body').on('click', '.socialite-instance', trackBasic)) || $('body').delegate('.socialite-instance', 'click', trackBasic)

###
Kick off the jQuery check
###
check()

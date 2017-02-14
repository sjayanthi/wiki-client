# The siteAdapter handles fetching resources from sites, including origin
# and local browser storage.

module.exports = siteAdapter = {}

# we save the site prefix once we have determined it...
sitePrefix = {}

# when asked for a site's flag, if we don't know the current prefix we create
# a temporary greyscale flag. We save them here, so we can replace them when
# we know how to get a site's flag
tempFlags = {}

findAdapter = (site) ->
  test: (url, done) ->
    this.inuse = true
    this.callback = done
    _that = this
    this.img = new Image()
    this.img.onload = () ->
      _that.inuse = false
      _that.callback(true)
    this.img.onerror = (e) ->
      if _that.inuse
        _that.inuse = false
        _that.callback(false)
    this.start = new Date().getTime()
    this.img.src = url
    this.timer =setTimeout( () ->
      if _that.inuse
        _that.inuse = false
        _that.callback(false)
    , 1500)

  prefix: (done) ->
    console.log "findPrefix for #{site}"
    if sitePrefix[site]?
      done sitePrefix[site]

    testURL = "//#{site}/favicon.png"
    this.test testURL, (worked) ->
      if worked
        sitePrefix[site] = "//#{site}"
        done "//#{site}"
      else
        switch location.protocol
          when 'http:'
            testURL = "https://#{site}/favicon.png"
            this.test testURL, (worked) ->
              if worked
                sitePrefix[site] = "https://#{site}"
                done "https://#{site}"
              else
                #
                sitePrefix[site] = "//#{site}"
                done "//#{site}"
          when 'https:'
            testURL = "/proxy/#{site}/favicon.png"
            this.test testURL, (worked) ->
              if worked
                sitePrefix[site] = "/proxy/#{site}"
                done "/proxy/#{site}"
              else
                #
                sitePrefix[site] = "//#{site}"
                done "//#{site}"
          else
            # if we are here we have a different the origin on a different protocol
            # maybe we should try https and http, but that's for later...
            sitePrefix[site] = "//#{site}"
            done "//#{site}"

siteAdapter.local = {
  flag: -> "/favicon.png?adapted"
  get: (route, done) ->
    console.log "wiki.local.get #{route}"
    if page = localStorage.getItem(route.replace(/\.json$/,''))
      done null, JSON.parse page
    else
      done {msg: "no page named '#{route}' in browser local storage"}
}

siteAdapter.origin = {
  flag: -> "/favicon.png?adapted"
  get: (route, done) ->
    console.log "wiki.origin.get #{route}"
    $.ajax
      type: 'GET'
      dataType: 'json'
      url: "/#{route}?adapted"
      success: (page) -> done null, page
      error: (xhr, type, msg) -> done {msg, xhr}, null
}

siteAdapter.site = (site) ->
  return siteAdapter.origin if !site or site is window.location.host

  createTempFlag = (site) ->
    console.log "creating temp flags for #{site}"
    myCanvas = document.createElement('canvas')
    myCanvas.width = 32
    myCanvas.height = 32

    ctx = myCanvas.getContext('2d')

    x1 = Math.random() * 32
    y1 = x1
    y2 = Math.random() * 32
    x2 = 32 - y2

    c1 = (Math.random() * 0xFF<<0).toString(16)
    c2 = (Math.random() * 0xFF<<0).toString(16)

    color1 = '#' + c1 + c1 + c1
    color2 = '#' + c2 + c2 + c2


    gradient = ctx.createRadialGradient(x1,y1,32,x2,y2,0)
    gradient.addColorStop(0, color1)
    gradient.addColorStop(1, color2)
    ctx.fillStyle = gradient
    ctx.fillRect(0,0,32,32)
    myCanvas.toDataURL()

  {
    flag: ->
      if sitePrefix[site]?
        # we already know how to construct flag url
        sitePrefix[site] + "/favicon.png?adapted"
      else if tempFlags[site]?
        # we already have a temp. flag
        console.log "wiki.site(#{site}).flag - have temp. flag"
        tempFlags[site]
      else
        # we don't know the url to the real flag, or have a temp flag

        findAdapter(site).prefix (prefix) ->
          console.log "Prefix for #{site} is #{prefix}"
          # replace temp flags
          tempFlag = tempFlags[site]
          realFlag = sitePrefix[site] + "/favicon.png?replaceTemp"
          # replace temporary flag where it is used as an image
          $('img[src="' + tempFlag + '"]').attr('src', realFlag)
          # replace temporary flag where its used as a background to fork event in journal
          $('a[target="' + site + '"]').attr('style', 'background-image: url(' + realFlag + ')')

        # create a temp flag, save it for reuse, and return it
        tempFlag = createTempFlag(site)
        tempFlags[site] = tempFlag
        tempFlag

    get: (route, cb) ->

  }

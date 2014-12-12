#
# Axis Labels Plugin for flot.
# http://github.com/markrcote/flot-axislabels
#
# Axis Labels Plugin for flot, Coffeescript version
# https://github.com/StefanDorresteijn/Flot-Axislabels-Coffeescript
#
# Original code is Copyright (c) 2010 Xuan Luo.
# Coffeescript code is Copyright (c) 2014 Stefan Dorresteijn.
# Original code was released under the GPLv3 license by Xuan Luo, September 2010.
# Original code was rereleased under the MIT license by Xuan Luo, April 2012.
# Coffeescript version was rereleased under the MIT license by Stefan Dorresteijn, December 2014.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(($) ->
  canvasSupported = ->
    !!document.createElement("canvas").getContext
  canvasTextSupported = ->
    return false  unless canvasSupported()
    dummy_canvas = document.createElement("canvas")
    context = dummy_canvas.getContext("2d")
    typeof context.fillText is "function"
  css3TransitionSupported = ->
    div = document.createElement("div")
    # Gecko
    # Opera
    # WebKit
    typeof div.style.MozTransition isnt "undefined" or typeof div.style.OTransition isnt "undefined" or typeof div.style.webkitTransition isnt "undefined" or typeof div.style.transition isnt "undefined"
  AxisLabel = (axisName, position, padding, plot, opts) ->
    @axisName = axisName
    @position = position
    @padding = padding
    @plot = plot
    @opts = opts
    @width = 0
    @height = 0
    return
  CanvasAxisLabel = (axisName, position, padding, plot, opts) ->
    AxisLabel::constructor.call this, axisName, position, padding, plot, opts
    return
  HtmlAxisLabel = (axisName, position, padding, plot, opts) ->
    AxisLabel::constructor.call this, axisName, position, padding, plot, opts
    @elem = null
    return
  
  # store height and width of label itself, for use in draw()
  CssTransformAxisLabel = (axisName, position, padding, plot, opts) ->
    HtmlAxisLabel::constructor.call this, axisName, position, padding, plot, opts
    return
  IeTransformAxisLabel = (axisName, position, padding, plot, opts) ->
    CssTransformAxisLabel::constructor.call this, axisName, position, padding, plot, opts
    @requiresResize = false
    return
  
  # I didn't feel like learning the crazy Matrix stuff, so this uses
  # a combination of the rotation transform and CSS positioning.
  
  # see below
  
  # adjust some values to take into account differences between
  # CSS and IE rotations.
  
  # FIXME: not sure why, but placing this exactly at the top causes
  # the top axis label to flip to the bottom...
  
  # Since we used CSS positioning instead of transforms for
  # translating the element, and since the positioning is done
  # before any rotations, we have to reset the width and height
  # in case the browser wrapped the text (specifically for the
  # y2axis).
  init = (plot) ->
    plot.hooks.processOptions.push (plot, options) ->
      return  unless options.axisLabels.show
      
      # This is kind of a hack. There are no hooks in Flot between
      # the creation and measuring of the ticks (setTicks, measureTickLabels
      # in setupGrid() ) and the drawing of the ticks and plot box
      # (insertAxisLabels in setupGrid() ).
      #
      # Therefore, we use a trick where we run the draw routine twice:
      # the first time to get the tick measurements, so that we can change
      # them, and then have it draw it again.
      secondPass = false
      axisLabels = {}
      axisOffsetCounts =
        left: 0
        right: 0
        top: 0
        bottom: 0

      defaultPadding = 2 # padding between axis and tick labels
      plot.hooks.draw.push (plot, ctx) ->
        hasAxisLabels = false
        unless secondPass
          
          # MEASURE AND SET OPTIONS
          $.each plot.getAxes(), (axisName, axis) ->
            # Flot 0.7
            opts = axis.options or plot.getOptions()[axisName] # Flot 0.6
            
            # Handle redraws initiated outside of this plug-in.
            if axisName of axisLabels
              axis.labelHeight = axis.labelHeight - axisLabels[axisName].height
              axis.labelWidth = axis.labelWidth - axisLabels[axisName].width
              opts.labelHeight = axis.labelHeight
              opts.labelWidth = axis.labelWidth
              axisLabels[axisName].cleanup()
              delete axisLabels[axisName]
            return  if not opts or not opts.axisLabel or not axis.show
            hasAxisLabels = true
            renderer = null
            if not opts.axisLabelUseHtml and navigator.appName is "Microsoft Internet Explorer"
              ua = navigator.userAgent
              re = new RegExp("MSIE ([0-9]{1,}[.0-9]{0,})")
              rv = parseFloat(RegExp.$1)  if re.exec(ua)?
              if rv >= 9 and not opts.axisLabelUseCanvas and not opts.axisLabelUseHtml
                renderer = CssTransformAxisLabel
              else if not opts.axisLabelUseCanvas and not opts.axisLabelUseHtml
                renderer = IeTransformAxisLabel
              else if opts.axisLabelUseCanvas
                renderer = CanvasAxisLabel
              else
                renderer = HtmlAxisLabel
            else
              if opts.axisLabelUseHtml or (not css3TransitionSupported() and not canvasTextSupported()) and not opts.axisLabelUseCanvas
                renderer = HtmlAxisLabel
              else if opts.axisLabelUseCanvas or not css3TransitionSupported()
                renderer = CanvasAxisLabel
              else
                renderer = CssTransformAxisLabel
            padding = (if opts.axisLabelPadding is `undefined` then defaultPadding else opts.axisLabelPadding)
            axisLabels[axisName] = new renderer(axisName, axis.position, padding, plot, opts)
            
            # flot interprets axis.labelHeight and .labelWidth as
            # the height and width of the tick labels. We increase
            # these values to make room for the axis label and
            # padding.
            axisLabels[axisName].calculateSize()
            
            # AxisLabel.height and .width are the size of the
            # axis label and padding.
            # Just set opts here because axis will be sorted out on
            # the redraw.
            opts.labelHeight = axis.labelHeight + axisLabels[axisName].height
            opts.labelWidth = axis.labelWidth + axisLabels[axisName].width
            return

          
          # If there are axis labels, re-draw with new label widths and
          # heights.
          if hasAxisLabels
            secondPass = true
            plot.setupGrid()
            plot.draw()
        else
          secondPass = false
          
          # DRAW
          $.each plot.getAxes(), (axisName, axis) ->
            # Flot 0.7
            opts = axis.options or plot.getOptions()[axisName] # Flot 0.6
            return  if not opts or not opts.axisLabel or not axis.show
            axisLabels[axisName].draw axis.box
            return

        return

      return

    return
  options = axisLabels:
    show: true

  AxisLabel::cleanup = ->

  CanvasAxisLabel:: = new AxisLabel()
  CanvasAxisLabel::constructor = CanvasAxisLabel
  CanvasAxisLabel::calculateSize = ->
    @opts.axisLabelFontSizePixels = 14  unless @opts.axisLabelFontSizePixels
    @opts.axisLabelFontFamily = "sans-serif"  unless @opts.axisLabelFontFamily
    textWidth = @opts.axisLabelFontSizePixels + @padding
    textHeight = @opts.axisLabelFontSizePixels + @padding
    if @position is "left" or @position is "right"
      @width = @opts.axisLabelFontSizePixels + @padding
      @height = 0
    else
      @width = 0
      @height = @opts.axisLabelFontSizePixels + @padding
    return

  CanvasAxisLabel::draw = (box) ->
    @opts.axisLabelColour = "black"  unless @opts.axisLabelColour
    ctx = @plot.getCanvas().getContext("2d")
    ctx.save()
    ctx.font = @opts.axisLabelFontSizePixels + "px " + @opts.axisLabelFontFamily
    ctx.fillStyle = @opts.axisLabelColour
    width = ctx.measureText(@opts.axisLabel).width
    height = @opts.axisLabelFontSizePixels
    x = undefined
    y = undefined
    angle = 0
    if @position is "top"
      x = box.left + box.width / 2 - width / 2
      y = box.top + height * 0.72
    else if @position is "bottom"
      x = box.left + box.width / 2 - width / 2
      y = box.top + box.height - height * 0.72
    else if @position is "left"
      x = box.left + height * 0.72
      y = box.height / 2 + box.top + width / 2
      angle = -Math.PI / 2
    else if @position is "right"
      x = box.left + box.width - height * 0.72
      y = box.height / 2 + box.top - width / 2
      angle = Math.PI / 2
    ctx.translate x, y
    ctx.rotate angle
    ctx.fillText @opts.axisLabel, 0, 0
    ctx.restore()
    return

  HtmlAxisLabel:: = new AxisLabel()
  HtmlAxisLabel::constructor = HtmlAxisLabel
  HtmlAxisLabel::calculateSize = ->
    elem = $("<div class=\"axisLabels\" style=\"position:absolute;\">" + @opts.axisLabel + "</div>")
    @plot.getPlaceholder().append elem
    @labelWidth = elem.outerWidth(true)
    @labelHeight = elem.outerHeight(true)
    elem.remove()
    @width = @height = 0
    if @position is "left" or @position is "right"
      @width = @labelWidth + @padding
    else
      @height = @labelHeight + @padding
    return

  HtmlAxisLabel::cleanup = ->
    @elem.remove()  if @elem
    return

  HtmlAxisLabel::draw = (box) ->
    @plot.getPlaceholder().find("#" + @axisName + "Label").remove()
    @elem = $("<div id=\"" + @axisName + "Label\" \" class=\"axisLabels\" style=\"position:absolute;\">" + @opts.axisLabel + "</div>")
    @plot.getPlaceholder().append @elem
    if @position is "top"
      @elem.css "left", box.left + box.width / 2 - @labelWidth / 2 + "px"
      @elem.css "top", box.top + "px"
    else if @position is "bottom"
      @elem.css "left", box.left + box.width / 2 - @labelWidth / 2 + "px"
      @elem.css "top", box.top + box.height - @labelHeight + "px"
    else if @position is "left"
      @elem.css "top", box.top + box.height / 2 - @labelHeight / 2 + "px"
      @elem.css "left", box.left + "px"
    else if @position is "right"
      @elem.css "top", box.top + box.height / 2 - @labelHeight / 2 + "px"
      @elem.css "left", box.left + box.width - @labelWidth + "px"
    return

  CssTransformAxisLabel:: = new HtmlAxisLabel()
  CssTransformAxisLabel::constructor = CssTransformAxisLabel
  CssTransformAxisLabel::calculateSize = ->
    HtmlAxisLabel::calculateSize.call this
    @width = @height = 0
    if @position is "left" or @position is "right"
      @width = @labelHeight + @padding
    else
      @height = @labelHeight + @padding
    return

  CssTransformAxisLabel::transforms = (degrees, x, y) ->
    stransforms =
      "-moz-transform": ""
      "-webkit-transform": ""
      "-o-transform": ""
      "-ms-transform": ""

    if x isnt 0 or y isnt 0
      stdTranslate = " translate(" + x + "px, " + y + "px)"
      stransforms["-moz-transform"] += stdTranslate
      stransforms["-webkit-transform"] += stdTranslate
      stransforms["-o-transform"] += stdTranslate
      stransforms["-ms-transform"] += stdTranslate
    unless degrees is 0
      rotation = degrees / 90
      stdRotate = " rotate(" + degrees + "deg)"
      stransforms["-moz-transform"] += stdRotate
      stransforms["-webkit-transform"] += stdRotate
      stransforms["-o-transform"] += stdRotate
      stransforms["-ms-transform"] += stdRotate
    s = "top: 0; left: 0; "
    for prop of stransforms
      s += prop + ":" + stransforms[prop] + ";"  if stransforms[prop]
    s += ";"
    s

  CssTransformAxisLabel::calculateOffsets = (box) ->
    offsets =
      x: 0
      y: 0
      degrees: 0

    if @position is "bottom"
      offsets.x = box.left + box.width / 2 - @labelWidth / 2
      offsets.y = box.top + box.height - @labelHeight
    else if @position is "top"
      offsets.x = box.left + box.width / 2 - @labelWidth / 2
      offsets.y = box.top
    else if @position is "left"
      offsets.degrees = -90
      offsets.x = box.left - @labelWidth / 2 + @labelHeight / 2
      offsets.y = box.height / 2 + box.top
    else if @position is "right"
      offsets.degrees = 90
      offsets.x = box.left + box.width - @labelWidth / 2 - @labelHeight / 2
      offsets.y = box.height / 2 + box.top
    offsets.x = Math.round(offsets.x)
    offsets.y = Math.round(offsets.y)
    offsets

  CssTransformAxisLabel::draw = (box) ->
    @plot.getPlaceholder().find("." + @axisName + "Label").remove()
    offsets = @calculateOffsets(box)
    @elem = $("<div class=\"axisLabels " + @axisName + "Label\" style=\"position:absolute; " + @transforms(offsets.degrees, offsets.x, offsets.y) + "\">" + @opts.axisLabel + "</div>")
    @plot.getPlaceholder().append @elem
    return

  IeTransformAxisLabel:: = new CssTransformAxisLabel()
  IeTransformAxisLabel::constructor = IeTransformAxisLabel
  IeTransformAxisLabel::transforms = (degrees, x, y) ->
    s = ""
    unless degrees is 0
      rotation = degrees / 90
      rotation += 4  while rotation < 0
      s += " filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=" + rotation + "); "
      @requiresResize = (@position is "right")
    s += "left: " + x + "px; "  unless x is 0
    s += "top: " + y + "px; "  unless y is 0
    s

  IeTransformAxisLabel::calculateOffsets = (box) ->
    offsets = CssTransformAxisLabel::calculateOffsets.call(this, box)
    if @position is "top"
      offsets.y = box.top + 1
    else if @position is "left"
      offsets.x = box.left
      offsets.y = box.height / 2 + box.top - @labelWidth / 2
    else if @position is "right"
      offsets.x = box.left + box.width - @labelHeight
      offsets.y = box.height / 2 + box.top - @labelWidth / 2
    offsets

  IeTransformAxisLabel::draw = (box) ->
    CssTransformAxisLabel::draw.call this, box
    if @requiresResize
      @elem = @plot.getPlaceholder().find("." + @axisName + "Label")
      @elem.css "width", @labelWidth
      @elem.css "height", @labelHeight
    return

  $.plot.plugins.push
    init: init
    options: options
    name: "axisLabels"
    version: "2.0"

  return
) jQuery
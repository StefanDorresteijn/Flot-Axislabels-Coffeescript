Flot-Axislabels-Coffeescript
============================

https://github.com/markrcote/flot-axislabels translated to CoffeeScript.

Code remains entirely unchanged except for the translation to CoffeeScript and is used in the exact same way as the original. 

**Usage example**

    graphPlot = $.plot($("#graph-lines"), graphData,
      axisLabels:
        show: true
    
      series:
        lines:
          show: false
    
        shadowSize: 0
    
      grid:
        color: "#646464"
        borderColor: "#c3c3c3"
        borderWidth: 0
        hoverable: true
    
      xaxis:
        axisLabel: "fu"
        tickColor: "#c3cc3"
        min: 0
        max: 100
    
      yaxis:
        axisLabel: "bar"
        min: 0
        max: 100
        tickColor: "#c3c3c3"
    )
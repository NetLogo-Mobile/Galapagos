import RactiveWidget from "./widget.js"

genWidgetCreator = (name, widgetType, isEnabled = true, enabler = (-> false)) ->
  { text: "Create #{name}", enabler, isEnabled
  , action: (context, mouseX, mouseY) -> context.fire('create-widget', widgetType, mouseX, mouseY)
  }

alreadyHasA = (componentName) -> (ractive) ->
  if ractive.parent?
    alreadyHasA(componentName)(ractive.parent)
  else
    not ractive.findComponent(componentName)?

defaultOptions = [ ["Button",  "button"]
                 , ["Chooser", "chooser"]
                 , ["Input",   "inputBox"]
                 , ["Note",    "textBox"]
                 , ["Monitor", "monitor"]
                 , ["Output",  "output", false, alreadyHasA('outputWidget')]
                 , ["Plot",    "plot"]
                 , ["Slider",  "slider"]
                 , ["Switch",  "switch"]
                 ].map((args) -> genWidgetCreator(args...))

RactiveContextMenu = Ractive.extend({

  data: -> {
    options: undefined # ContextMenuOptions
  , mouseX:          0 # Number
  , mouseY:          0 # Number
  , target:  undefined # Ractive
  , visible:     false # Boolean
  }

  on: {

    'ignore-click': ->
      false

    'cover-thineself': ->
      @set('visible', false)
      @fire('unlock-selection')
      return

    'reveal-thineself': (_, component, x, y) ->

      @set('target' , component)
      @set('options', component?.get('contextMenuOptions') ? defaultOptions)
      @set('visible', @get('options').length > 0)
      @set('mouseX' , x)
      @set('mouseY' , y)

      if component instanceof RactiveWidget
        @fire('lock-selection', component)

      return

  }

  template:
    """
    {{# visible }}
    <div id="netlogo-widget-context-menu" class="widget-context-menu" style="top: {{mouseY}}px; left: {{mouseX}}px;">
      <div id="{{id}}-context-menu" class="netlogo-widget-editor-menu-items">
        <ul class="context-menu-list">
          {{# options }}
            {{# (..enabler !== undefined && ..enabler(target)) || ..isEnabled }}
              <li class="context-menu-item" on-mouseup="..action(target, mouseX, mouseY)">{{..text}}</li>
            {{ else }}
              <li class="context-menu-item disabled" on-mouseup="ignore-click">{{..text}}</li>
            {{/}}
          {{/}}
        </ul>
      </div>
    </div>
    {{/}}
    """

})

export default RactiveContextMenu

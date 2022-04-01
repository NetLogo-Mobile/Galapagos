import { RactiveTwoWayLabeledInput } from "/beak/widgets/ractives/subcomponent/labeled-input.js"
import { RactiveTwoWayDropdown } from "/beak/widgets/ractives/subcomponent/dropdown.js"
import RactiveBlockPreview from "./block-preview.js"
import RactiveAttributes from "./attributes.js"
import RactiveClauses from "./clauses.js"
import RactiveAllowedTags from "./allowed-tags.js"
import { RactiveToggleTags } from "./tags.js"
import RactiveBlockStyleSettings from "./block-style-settings.js"
import RactiveCodeMirror from "./code-mirror.js"
import NetTangoBlockDefaults from "./block-defaults.js"
import RactiveModalDialog from "./modal-dialog.js"

RactiveBlockForm = RactiveModalDialog.extend({

  data: () -> {
    spaceName:      undefined    # String
    block:          undefined    # NetTangoBlock
    blockIndex:     undefined    # Integer
    blockKnownTags: []           # Array[String]
    allTags:        []           # Array[String]
    terminalType:   "attachable" # "attachable" | "terminal"
    top:            200
  }

  computed: {

    terminalChoices: () ->
      [
        { value: "terminal",   text: "This will be the last block in its chain, no more blocks can attach" }
      , { value: "attachable", text: "Blocks can be attached to this block in a chain" }
      ]

    isProcedureBlock: () ->
      builderType = @get('builderType')
      builderType is 'Procedure'

  }

  on: {

    'init': () ->

      resetPreviewBlock = () ->
        if @get('active')
          previewBlock = @getBlock()
          @set('previewBlock', previewBlock)
        return

      skipInit = { init: false }
      @observe('block.*', resetPreviewBlock, skipInit)
      @observe('builderType', resetPreviewBlock, skipInit)
      @observe('terminalType', () ->
        terminalType = @get('terminalType')
        @set('block.isTerminal', terminalType is 'terminal')
        return
      , skipInit)
      return

      return

    '*.code-changed': (_, code) ->
      @set('block.format', code)

    '*.ntb-clear-styles': (_) ->
      block = @get('block')
      [ 'blockColor', 'textColor', 'borderColor', 'fontWeight', 'fontSize', 'fontFace' ]
        .forEach( (prop) -> block[prop] = '' )
      @set('block', block)
      return

  }

  # (NetTangoBlock) => Unit
  _setBlock: (sourceBlock) ->
    # Copy so we drop any uncommitted changes - JMB August 2018
    block = NetTangoBlockDefaults.copyBlock(sourceBlock)
    block.id = sourceBlock.id

    builderType =
      if (block.isRequired and block.placement is NetTango.blockPlacementOptions.STARTER)
        'Procedure'
      else if not block.isRequired and
      (not block.placement? or block.placement is NetTango.blockPlacementOptions.CHILD)
        'Command or Control'
      else
        'Custom'

    @set('block', block)
    @set('builderType', builderType)
    @set('previewBlock', block)
    return

  # () => NetTangoBlock
  getBlock: () ->
    blockValues = @get('block')
    builderType = @get('builderType')
    block = { }

    [
      'id'
    , 'action'
    , 'format'
    , 'closeClauses'
    , 'closeStarter'
    , 'note'
    , 'isRequired'
    , 'isTerminal'
    , 'placement'
    , 'limit'
    , 'blockColor'
    , 'textColor'
    , 'borderColor'
    , 'fontWeight'
    , 'fontSize'
    , 'fontFace'
    ].filter( (f) -> blockValues.hasOwnProperty(f) and blockValues[f] isnt '' )
      .forEach( (f) -> block[f] = blockValues[f] )

    switch builderType
      when 'Procedure'
        block.isRequired = true
        block.placement  = NetTango.blockPlacementOptions.STARTER

      when 'Command or Control'
        block.isRequired = false
        block.placement  = NetTango.blockPlacementOptions.CHILD

      else
        block.isRequired = blockValues.isRequired ? false
        block.placement  = blockValues.placement ? NetTango.blockPlacementOptions.CHILD

    block.tags        = blockValues.tags ? []
    block.clauses     = @processClauses(blockValues.clauses ? [])
    block.params      = @processAttributes(blockValues.params)
    block.properties  = @processAttributes(blockValues.properties)
    block.allowedTags = @processAllowedTags(blockValues.allowedTags)

    block

  processClauses: (clauses) ->
    pat = @processAllowedTags

    clauses.map( (clause) ->
      [ 'action', 'open', 'close' ].forEach( (f) ->
        if clause.hasOwnProperty(f) and clause[f] is ''
          delete clause[f]
      )

      clause.allowedTags = pat(clause.allowedTags)

      clause
    )

  # (Array[NetTangoAttribute]) => Array[NetTangoAttribute]
  processAttributes: (attributes) ->
    attributeCopies = for attrValues in attributes
      attribute = { }
      ['name', 'unit', 'type'].forEach( (f) -> attribute[f] = attrValues[f] )
      # Using `default` as a property name gives Ractive some issues, so we "translate" it back here - JMB August 2018
      attribute.default = attrValues.def
      # User may have switched type a couple times, so only copy the properties if the type is appropriate to them
      # - JMB August 2018
      switch attrValues.type
        when 'range'
          ['min', 'max', 'step'].forEach( (f) -> attribute[f] = attrValues[f] )

        when 'select'
          ['quoteValues'].forEach( (f) -> attribute[f] = attrValues[f] )
          attribute.values = attrValues.values

        when 'text'
          ['quoteValues'].forEach( (f) -> attribute[f] = attrValues[f] )

      attribute

    attributeCopies

  processAllowedTags: (allowedTags) ->
    if not allowedTags?
      return undefined

    if not ['any-of', 'none-of'].includes(allowedTags.type)
      delete allowedTags.tags

    allowedTags

  makeSubmitEventArgs: () ->
    # the user could've added a bunch of new known tags, but not wound up using them,
    # so ignore any that were not actually applied to the block - Jeremy B September 2020
    block          = @getBlock()
    blockKnownTags = @get('blockKnownTags')
    allTags        = @get('allTags')
    newKnownTags   = blockKnownTags.filter( (t) ->
      ( (block.tags? and block.tags.includes(t)) or
        (block.allowedTags?.tags? and block.allowedTags.tags.includes(t)) or
        (block.clauses.some( (c) -> c.allowedTags?.tags? and c.allowedTags.tags.includes(t) ))
      ) and
      not allTags.includes(t)
    )
    @push('allTags', ...newKnownTags)
    [block, @get('blockIndex')]

  # (Int, String, String, NetTangoBlock, Integer, String, String, String) => Unit
  show: (top, target, spaceName, block, blockIndex, submitLabel, submitEvent, cancelLabel) ->
    @set('spaceName', spaceName)
    @set('blockIndex', blockIndex)
    @set('terminalType', if block.isTerminal? and block.isTerminal then 'terminal' else 'attachable')
    @_setBlock(block)
    @set('blockKnownTags', @get('allTags').slice(0))
    @set('approve', {
      text: submitLabel
    , event: submitEvent
    , target: target
    , argsMaker: () => @makeSubmitEventArgs()
    })
    @set('deny', { text: cancelLabel })
    @_super(top)
    return

  components: {
    allowedTags:  RactiveAllowedTags
  , attributes:   RactiveAttributes
  , blockStyle:   RactiveBlockStyleSettings
  , clauses:      RactiveClauses
  , codeMirror:   RactiveCodeMirror
  , dropdown:     RactiveTwoWayDropdown
  , labeledInput: RactiveTwoWayLabeledInput
  , preview:      RactiveBlockPreview
  , tagsControl:  RactiveToggleTags
  }

  partials: {
    headerContent: "{{ spaceName }} Block"
    dialogContent:
      # coffeelint: disable=max_line_length
      """
      <div class="flex-row ntb-block-form">

      <div class="ntb-block-form-fields">
      {{# block }}

        <div class="flex-row ntb-form-row">

          <labeledInput id="block-{{ id }}-name" name="name" type="text" value="{{ action }}" labelStr="Display name"
            divClass="ntb-flex-column" class="ntb-input" />

          <dropdown id="block-{{ id }}-type" name="{{ builderType }}" selected="{{ builderType }}" label="Type"
            choices="{{ [ 'Procedure', 'Command or Control' ] }}"
            divClass="ntb-flex-column"
            />

          <labeledInput id="block-{{ id }}-limit" name="limit" type="number" value="{{ limit }}" labelStr="Limit"
            min="0" max="100" divClass="ntb-flex-column" class="ntb-input" />

        </div>

        <div class="ntb-flex-column">
          <label for="block-{{ id }}-format">NetLogo code format (use {#} for parameter, {P#} for property)</label>
          <codeMirror
            id="block-{{ id }}-format"
            mode="netlogo"
            code={{ format }}
            extraClasses="['ntb-code-input-big']"
          />
        </div>

        <div class="flex-row ntb-form-row">
          <labeledInput id="block-{{ id }}-note" name="note" type="text" value="{{ note }}"
            labelStr="Note - extra information for the code tip"
            divClass="ntb-flex-column" class="ntb-input" />
        </div>

        <div class="flex-row ntb-form-row">
          <dropdown id="block-{{ id }}-terminal" name="terminal" selected="{{ terminalType }}" label="Can blocks follow this one in a chain?"
            choices={{ terminalChoices }}
            divClass="ntb-flex-column"
            />
        </div>

        {{# isProcedureBlock }}
          <div class="flex-row ntb-form-row">
            <div class="ntb-flex-column">
              <label for="block-{{ id }}-close">Code format to insert after all attached blocks (default is `end`)</label>
              <codeMirror
                id="block-{{ id }}-close"
                mode="netlogo"
                code={{ closeStarter }}
                extraClasses="['ntb-code-input']"
                multilineClass="ntb-code-input-big"
              />
            </div>
          </div>

          {{# !isTerminal }}
          <div class="flex-row ntb-form-row">
            <allowedTags
              id="block-{{ id }}-allowed-tags"
              allowedTags={{ allowedTags }}
              knownTags={{ blockKnownTags }}
              blockType="starter"
              canInheritTags={{ !isProcedureBlock }}
              />
          </div>
          {{/ isTerminal}}

        {{/isProcedureBlock }}

        <tagsControl
          tags={{ tags }}
          knownTags={{ blockKnownTags }}
          showAtStart={{ tags.length > 0 }}
          areProcedureTags={{ isProcedureBlock }}
          />

        <attributes
          singular="Parameter"
          plural="Parameters"
          blockId={{ id }}
          attributes={{ params }}
          />

        <attributes
          singular="Property"
          plural="Properties"
          blockId={{ id }}
          attributes={{ properties }}
          codeFormat="P"
          />

        <clauses
          blockId={{ id }}
          clauses={{ clauses }}
          closeClauses={{ closeClauses }}
          knownTags={{ blockKnownTags }}
          forProcedureBlock={{ isProcedureBlock }}
          />

        <blockStyle styleId="{{ id }}" showAtStart=false styleSettings="{{ this }}"></blockStyle>

      {{/block }}
      </div>

      <preview block={{ previewBlock }} blockStyles={{ blockStyles }} />

      </div>
      """
      # coffeelint: enable=max_line_length
  }
})

export default RactiveBlockForm

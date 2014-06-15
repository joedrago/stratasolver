fs = require 'fs'
path = require 'path'

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance

quit = (reason) ->
  console.log "ERROR: #{reason}"
  process.exit()

class StrataSolver
  constructor: (@filename) ->
    # Read in lines, do some sanity checking
    lines = (line for line in fs.readFileSync(@filename, { encoding: 'utf-8' }).split(/\r|\n/) when line.length > 0)
    @dim = lines[0].length
    @stripes = @dim * 2
    @data = []
    for line in lines
      for i in [0...line.length]
        @data.push parseInt(line[i])

    saw = {}
    for d in @data
      saw[d] = true
    saw = Object.keys(saw)
    saw = saw.sort()
    saw = (parseInt(i) for i in saw)
    if saw[0] != 0
      saw.unshift(0)
    for i in [0...saw.length]
      if i != saw[i]
        quit "Using color #{saw[i]} without using color #{i}"
    @colors = saw.length - 1

    @puzzle = clone(@data)

  get: (x, y) ->
    return @data[ x + (y * @dim) ]

  set: (x, y, v) ->
    @data[ x + (y * @dim) ] = v

  distribution: (x) ->
    dist = Array(@stripes)
    for i in [0...@stripes]
      dist[i] = 0

    if x < @dim
      # left side
      for i in [0...@dim]
        dist[ @get(i, x) ]++
    else
      # bottom side
      for j in [0...@dim]
        dist[ @get(x - @dim, j) ]++

    return dist

  # if it returns false, it isn't a valid choice
  onlyColorInStripe: (x) ->
    color = false
    dist = @distribution(x)
    for i in [1...dist.length]
      if dist[i] > 0
        if color == false
          color = i
        else
          return false

    return color

  clearStripe: (x) ->
    if x < @dim
      # left side
      for i in [0...@dim]
        @set(i, x, 0)
    else
      # bottom side
      for j in [0...@dim]
        @set(x - @dim, j, 0)

  solve: ->
    @data = clone(@puzzle)
    used = []
    for i in [0...@stripes]
      used[i] = false
    moves = []
    lastColor = 0
    loop
      break if moves.length == @stripes
      nextStripe = 0
      nextColor = 0
      foundNextStripe = false
      for i in [0...@stripes]
        continue if used[i]
        onlyColor = @onlyColorInStripe(i)
        if onlyColor != false
          # console.log "can be next stripe: #{i} (using color #{onlyColor})"
          nextStripe = i
          nextColor = onlyColor
          foundNextStripe = true
          break

      if foundNextStripe
        moves.unshift {
          stripe: nextStripe + 1
          color: nextColor
        }
        lastColor = nextColor
        used[nextStripe] = true
        @clearStripe(nextStripe)
      else
        for v in @data
          if v != 0
            quit "unsolveable puzzle"

        for i in [0...@stripes]
          continue if used[i]
          moves.unshift {
            stripe: i + 1
            color: lastColor
          }

    return moves

main = ->
  args = process.argv.slice(2)
  if args.length != 1
    quit "Syntax: stratasolver filename"
  filename = args[0]
  solver = new StrataSolver(filename)
  moveList = solver.solve()
  lastColor = -1
  for move in moveList
    if lastColor != move.color
      console.log "* Color #{move.color}"
      lastColor = move.color
    console.log "          -> stripe #{move.stripe}"
  # console.log JSON.stringify(moveList, null, 2)

main()

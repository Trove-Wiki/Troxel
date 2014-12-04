fs = require 'fs'
exec = require('child_process').exec
global.IO = require '../coffee/IO.coffee'
QubicleIO = require '../coffee/Qubicle.io.coffee'
{Base64IO} = require '../coffee/Troxel.io.coffee'
require '../test/TestUtils.coffee'
cpus = require('os').cpus().length

SKIP_BLUEPRINTS = ['gm_prop_dungeon_largeblocker.blueprint', 'char_dream_monster_noise_large_torso.blueprint']

models = {}
jsonPath = process.cwd() + '/static/Trove.json'
process.chdir(process.argv[2] || 'C:/Program Files/Trove/')
fs.readdir 'blueprints', (err, files) ->
  throw err if err?
  toProcess = files.length
  failedBlueprints = []
  processedOne = ->
    if --toProcess == 0
      fs.writeFile jsonPath, JSON.stringify(models), -> thow err if err?
      count = Object.keys(models).length
      process.stdout.write "base64 data of #{count} blueprints successfully written to static/Trove.json\nskipped broken blueprints:\n\n"
      process.stdout.write "#{bp}, " for bp in failedBlueprints
      process.stdout.write "\n"
  processSny = -> # Trove doesn't like spawning 1k+ instances at the same time ;-)
    f = files.pop()
    return unless f? # all files processed
    if f.length > 10 and f.indexOf('.blueprint') == f.length - 10 and f not in SKIP_BLUEPRINTS
      exec 'devtool_dungeon_blueprint_to_QB.bat blueprints/' + f, {timeout: 5000},(err, stdout, stderr) ->
        # "Trove.exe -tool copyblueprint -generatemaps 1 blueprints/#{f} qbexport/#{f.substring(0, f.length - 10)}.qb"
        if err?
          failedBlueprints.push(f)
          processedOne()
          process.stdout.write "#{toProcess} blueprints remaining: skipped #{f} because of trove devtool not responding\n"
          return setImmediate processSny
        qbf = 'qbexport/' + f.substring 0, f.length - 10
        io = new QubicleIO m: qbf + '.qb', a: qbf + '_a.qb', t: qbf + '_t.qb', s: qbf + '_s.qb', ->
          if io.error or (io.x == 1 and io.y == 1 and io.z == 1 and !io.voxels[0]?)
            failedBlueprints.push(f)
            processedOne()
            return process.stdout.write "#{toProcess} blueprints remaining: skipped #{f} because of invalid qubicle matrix height\n"
          models[f.substring(0, f.length - 10)] = new Base64IO(io).export(true)
          processedOne()
          process.stdout.write "#{toProcess} blueprints remaining: #{f}\n"
        setImmediate processSny
    else
      processedOne()
      process.stdout.write "#{toProcess} blueprints remaining: skipped #{f} because not a blueprint\n"
      setImmediate processSny
  processSny() for i in [0...cpus] by 1

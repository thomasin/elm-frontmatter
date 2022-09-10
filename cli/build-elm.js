const path = require('path')
const fs = require('fs-extra')
var temp = require('temp').track()
const spawn = require('cross-spawn')
const getExecutable = require('elm-tooling/getExecutable')


async function buildElm(rejectProgram, config, outputDir, dirPath) {
    await fs.mkdir(path.join(dirPath, './cli/'))

    try {
        await combineDependencies(config, dirPath)
    } catch (err) {
        rejectProgram(err)
        return
    }

    // Copy the user created Content.elm file into the temporary directory.
    await fs.copy(path.join(outputDir, './Content.elm'), path.join(dirPath, './cli/elm/src/Content.elm'))

    // Copy the node package Elm code into the temporary directory.
    await fs.copy(path.join(__dirname, './elm/src/'), path.join(dirPath, './cli/elm/src/'))

    try {
        const result = spawn.sync('elm', ['make', './elm/src/Main.elm', '--output', '../elm.js'], {
            cwd: path.join(dirPath, 'cli'),
            stdio: ['ignore', 'ignore', 'inherit']
        })

        if (result.status) {
            throw new Error()
        }

        const { Elm } = require(path.join(dirPath, './elm.js'))

        return Elm.Main.init({
            flags: {
                pathSep: path.sep
            }
        })
    } catch (err) {
        rejectProgram("Error compiling Elm program")
    }
}


async function combineDependencies(config, dirPath) {
    const userElmJsonFile = await fs.readFile(path.join(process.cwd(), config.elmJsonDir, './elm.json'))
    const userElmJson = JSON.parse(userElmJsonFile)

    const cliElmJsonFile = await fs.readFile(path.join(__dirname, './elm.json'))
    const cliElmJson = JSON.parse(cliElmJsonFile)

    if (!userElmJson.dependencies.direct) {
        throw new Error(`elm.json file at '${path.join(process.cwd(), config.elmJsonDir, './elm.json')}' has no direct dependencies. Make sure it is not a package elm.json`)
    }

    try {
        const elmJsonAbsolutePath = await getElmJsonAbsolutePath()

        const result = spawn.sync(elmJsonAbsolutePath,
            [
                'solve',
                '--extra',
                ...Object.entries(userElmJson.dependencies.direct).map(([key, value]) => {
                    return `${key}@${value}`
                }),
                '--',
                path.join(__dirname, './elm.json'),
            ],
            {
                silent: true,
                env: process.env,
            }
        )

        await fs.writeFile(path.join(dirPath, './cli/elm.json'), JSON.stringify({ ...cliElmJson, dependencies: JSON.parse(result.stdout) }))
    } catch (err) {
        throw new Error("Error compiling Elm program", err)
    }
}


function get_dependencies(pathToElmJson) {
  var result = spawn.sync(
    'elm-json',
    [
      'solve',
      '--test',
      '--extra',
      'elm/core',
      'elm/json',
      'elm/time',
      'elm/random',
      '--',
      pathToElmJson,
    ],
    {
      silent: true,
      env: process.env,
    }
  );

  if (result.status != 0) {
    console.error(result.stderr.toString());
    process.exit(1);
    return {};
  }

  return JSON.parse(result.stdout.toString());
}


function getElmJsonAbsolutePath() {
    return getExecutable({
      name: 'elm-json',
      version: '^0.2.10',
      onProgress: (percentage) => {}
    })
}


module.exports = buildElm

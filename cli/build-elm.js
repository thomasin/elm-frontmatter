const path = require('path')
const fs = require('fs-extra')
var temp = require('temp').track()
const spawn = require('cross-spawn')


async function buildElm (config, dirPath) {
    // Copy the user created Content.elm file into the temporary directory.
    await fs.copy(path.join(process.cwd(), config.outputDir, './Content.elm'), path.join(dirPath, './src/Content.elm'))

    // Copy the node package Elm code into the temporary directory.
    await fs.copy(path.join(__dirname, './elm/src/'), path.join(dirPath, './cli/elm/src/'))

    // Copy the node package elm.json into the temporary directory.
    await fs.copy(path.join(__dirname, './elm.json'), path.join(dirPath, './cli/elm.json'))

    // Copy the Elm package files into the temporary directory.
    await fs.copy(path.join(__dirname, '../src/'), path.join(dirPath, './src/'))

    try {
        spawn.sync('elm', ['make', './elm/src/Main.elm', '--output', '../elm.js'], {
            cwd: path.join(dirPath, 'cli'),
            stdio: ['ignore', 'ignore', 'inherit']
        })

        const { Elm } = require(path.join(dirPath, './elm.js'))

        return Elm.Main.init({
            flags: {
                pathSep: path.sep
            }
        })
    } catch (err) {
        console.error(err)
        throw new Error("Error compiling Elm program")
    }
}


module.exports = buildElm

#!/usr/bin/env node

const matter = require('gray-matter');
const sharp = require('sharp');
const yaml = require('js-yaml');
const fs = require('fs-extra')
const glob = require('glob')
const path = require('path')
const spawn = require('cross-spawn')
var temp = require('temp').track()
const chalk = require('chalk')
const prompts = require('prompts')
const commandLineArgs = require('command-line-args')

const buildElm = require('./cli/build-elm.js')
const plugins = require('./cli/plugins.js')

//

const args = commandLineArgs([
  { name: 'src', defaultOption: true, defaultValue: './content/' },
  { name: 'glob', type: String, defaultValue: '**/*.md' },
  { name: 'elm-json-dir', type: String, defaultValue: '.', description: `The folder containing your app's elm.json file` },
  { name: 'elm-dir', type: String, description: `The folder containing your app's elm files (usually ./src)` },
  { name: 'yes', alias: 'y', type: Boolean },
])

if (args.yes && !args['elm-dir']) {
    console.log(chalk.red('You cannot use the --yes/-y flag without also specifying --elm-dir'))
    return
}

const config = {
    inputDir: args.src,
    inputGlob: args.glob,
    elmJsonDir: args['elm-json-dir'],
    elmDir: args['elm-dir'] || './src/' 
}

async function fileGlob() {
    return new Promise(async (resolveProgram, rejectProgram) => {
        const userElmJsonFile = await fs.readFile(path.join(process.cwd(), config.elmJsonDir, './elm.json'))
        const userElmJson = JSON.parse(userElmJsonFile)
        const elmDir = path.join(process.cwd(), config.elmDir) || path.join(process.cwd(), config.elmJsonDir, userElmJson['source-directories'][0])

        const absoluteFilePaths = glob.sync(path.join(process.cwd(), config.inputDir, config.inputGlob), {})
        const tempDir = await temp.mkdir('elm-frontmatter')
        const elmApp = await buildElm(rejectProgram, config, elmDir, tempDir)

        if (!elmApp) { return }

        /* End the program */
        elmApp.ports.terminate.subscribe(rejectProgram)

        /* Show a message */
        elmApp.ports.show.subscribe((messages) => {
            messages.map((message) => {
                switch (message.level) {
                    case 'success':
                        console.log(chalk.green(message.message))
                        break

                    case 'info':
                        console.log(chalk.blue(message.message))
                        break
                }
            })
        })


        /* Finished performing all side effects, this function writes all of the generated Elm code to disk */
        elmApp.ports.writeFiles.subscribe(async (filesToWrite) => {
            try {
                await Promise.all(filesToWrite.map(({ filePath, fileContents }) => {
                    return fs.outputFile(path.join(tempDir, '/output/', filePath), fileContents, { encoding: 'utf8' })
                }))

                const response = args.yes || await prompts({
                    type: 'confirm',
                    name: 'accepted',
                    message: 'Overwrite the ' + path.join(elmDir, 'Content') + ' directory?'
                })

                if (args.yes || response.accepted) {
                    await fs.emptyDir(path.join(elmDir, 'Content'))
                    await fs.copy(path.join(tempDir, '/output/'), path.join(elmDir))

                    console.log(chalk.bold.green("\nAll files written ✍️"))

                    const result = spawn.sync('npx', ['elm-format', '--elm-version=0.19', '--yes', path.join(elmDir, 'Content')], {
                        stdio: ['ignore', 'ignore', 'ignore']
                    })
                } else {
                    rejectProgram("User cancelled")
                }
            } catch (err) {
                rejectProgram(err)
            }
        })


        /* Perform a side effect like copying/resizing images */
        elmApp.ports.performEffect.subscribe(async (file) => {
            // TO-DO: Ask for permission to do file generation
            try {
                await Promise.all(file.actions.map((action) => {
                    if (plugins[action.with]) {
                        return plugins[action.with](config, action.args)
                    }
                }))

                elmApp.ports.effectsPerformed.send(file.filePath)
            } catch (err) {
                rejectProgram(err)
            }
        })

        /* Send all of the input files and their contents to the Elm app */
        await Promise.all(absoluteFilePaths.map(async (filePath) => {
            const fileString = await fs.readFile(filePath, { encoding: 'utf8' })

            elmApp.ports.add.send({
                filePath: path.relative(path.join(process.cwd(), config.inputDir), filePath),
                fileFrontmatter: matter(fileString, {
                  engines: {
                    yaml: s => yaml.load(s, { schema: yaml.JSON_SCHEMA })
                  }
                }),
            })
        }))


        /* Once all the files have been sent, the Elm app can start to decode them  */
        elmApp.ports.noMoreInputFiles.send(absoluteFilePaths.length)
    }).catch((terminationError) => {
        console.log(chalk.bold.red("🚨 Content generation terminated 🚨\n"))
        console.log(chalk.red(terminationError))
        console.log('\n')
    })
}

fileGlob()



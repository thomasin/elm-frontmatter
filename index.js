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

const buildElm = require('./cli/build-elm.js')
const plugins = require('./cli/plugins.js')

//

defaultConfig = {
    inputDir: './content/',
    inputGlob: '**/*.md',
    elmDir: './src/',
}

const userProvidedConfig = require(path.join(process.cwd(), './frontmatter.config.js'))
const config =  { ...defaultConfig, ...userProvidedConfig }


async function fileGlob() {
    return new Promise(async (resolveProgram, rejectProgram) => {
        const absoluteFilePaths = glob.sync(path.join(process.cwd(), config.inputDir, config.inputGlob), {})
        const tempDir = await temp.mkdir('elm-frontmatter')
        const elmApp = await buildElm(config, tempDir)


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

                const response = await prompts({
                    type: 'confirm',
                    name: 'accepted',
                    message: 'Overwrite the ' + path.join(process.cwd(), config.elmDir, 'Content') + ' directory?'
                })

                if (response.accepted) {
                    await fs.emptyDir(path.join(process.cwd(), config.elmDir, 'Content'))
                    await fs.copy(path.join(tempDir, '/output/'), path.join(process.cwd(), config.elmDir))

                    console.log(chalk.bold.green("\nAll files written ✍️"))

                    const result = spawn.sync('npx', ['elm-format', '--elm-version=0.19', '--yes', path.join(process.cwd(), config.elmDir, 'Content')], {
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



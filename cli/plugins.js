const path = require('path');
const fs = require('fs-extra');
const sharp = require('sharp');

const plugins = {
    async image (config, args) {
        try {
            const copyFrom = path.join(process.cwd(), config.inputDir, args.paths.copyFromBase, '..', args.paths.copyFromPath)
            const copyTo = path.join(process.cwd(), args.paths.copyToPath, args.paths.fileName)

            const sharpFunctions = {
                width: (image, width) => image.resize(width),
            }

            await fs.ensureDir(path.dirname(copyTo))

            const manipulatedImage = args.manipulations.reduce((image, manipulation) => {
                if (sharpFunctions[manipulation.function]) {
                    return sharpFunctions[manipulation.function](image, manipulation.args)
                } else {
                    return image
                }
            }, sharp(copyFrom))

            await manipulatedImage.toFile(copyTo)
        } catch (err) {
            throw err
        }
    }
}

module.exports = plugins

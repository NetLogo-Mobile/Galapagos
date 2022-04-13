import { nodeResolve } from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import sourcemaps from 'rollup-plugin-sourcemaps';
import { terser } from "rollup-plugin-terser";
import fs from "fs";
import path from "path";

export default ({ "config-sourceDir": sourceDir, "config-targetDir": targetDir }) => {

  const isDevelopment = process.env.NODE_ENV === "development"
  const inputDir = `${sourceDir}/javascripts`;
  const outputDir = `${targetDir}/javascripts`;

  // In development the `sourcemaps` plugin allows Rollup to read sourcemaps produced by sbt-coffeescript.
  // In production, we use `terser` to minify the bundle. - David D. 7/2021
  const devOnlyPlugins = [sourcemaps()];
  const prodOnlyPlugins = [terser()];

  const plugins = [

    nodeResolve({ browser: true }),

    commonjs(),

    // We want to use absolute paths in `import` statements, but don't want to use needlessly long paths from the
    // project root. This custom Rollup resolver allows setting a base directory for absolute imports. - David D. 7/2021
    absoluteImportBasePlugin(inputDir),

    ...(isDevelopment ? devOnlyPlugins : prodOnlyPlugins),

  ];

  return [
    // All files in the '/pages' directory are considered bundle entry points. We list the files using the 'fs' API, so
    // the config doesn't need to be updated every time we add a new page. - David D. 7/2021
    pagesConfig(fs.readdirSync(path.join(inputDir, "pages")).map(page => `pages/${page}`)),

    // For the standalone mode of 'simulation.scala.html' and 'netTangoBuilder.scala.html', we create a standalone
    // script bundle without code splitting, so it can be included as an inline script, which doesn't have any imports.
    // - David D. 7/2021
    standaloneBundleConfig("pages/simulation.js"),
    standaloneBundleConfig("pages/netTangoBuilder.js"),

    // Files imported in tests are transformed to commonjs, because tests run in Node. - David D. 7/2021
    ...testInputsConfig([
      "beak/tortoise-utils.js"
    ]),
  ];

  // Generates a bundle configuration for a list of page entries.
  function pagesConfig(entryFiles) {
    const bundleInputs = {};
    for (let file of entryFiles) {
      const [path, extension] = splitExtension(file)
      bundleInputs[path] = `${inputDir}/${path}${extension}`;
    }

    return {
      input: bundleInputs,
      output: {
        dir: outputDir,
        format: "esm",
        sourcemap: isDevelopment,
        // In development, we keep the individual script files instead of bundling everything, so quickly finding code
        // from a specific file is easier. - David D. 7/2021
        preserveModules: isDevelopment,
        preserveModulesRoot: `${inputDir}/pages`,
        chunkFileNames: "[hash].chunk.js",
      },
      plugins,
      context: "this",
    };
  }

  // Generates a bundle configuration for a full standalone bundle with the given entry.
  function standaloneBundleConfig(entryFile) {
    const [path, extension] = splitExtension(entryFile)
    return {
      input: `${inputDir}/${path}${extension}`,
      output: {
        file: `${outputDir}/${path}.bundle${extension}`,
        sourcemap: isDevelopment,
      },
      plugins,
      context: "this",
    };
  }

  // Generates a bundle configuration for the given test entry files.
  function testInputsConfig(entryFiles) {
    // Unfortunately, SBT-Web always runs the production pipelineStages before running tests, so there is no way to
    // produce testBundles only when testing. But we can at least avoid bundling test inputs in development mode.
    // - David D. 7/2021
    if (isDevelopment) return [];

    const bundleInputs = {};
    for (let file of entryFiles) {
      const [path, extension] = splitExtension(file)
      bundleInputs[path] = `${inputDir}/${path}${extension}`;
    }

    return [{
      input: bundleInputs,
      output: {
        format: "cjs",
        dir: outputDir,
      },
    }];
  }
}

// Splits a path into a file name and an extension. An extension is anything after the last '.'.
// For example: splitExtension("foo/bar.js") = ["foo/bar", ".js"].
function splitExtension(path) {
  const splitAt = path.lastIndexOf(".");
  if (splitAt === -1) return [path, ""];
  return [path.substring(0, splitAt), path.substring(splitAt)]
}

// A simple Rollup plugin to define a base directory for absolute imports.
//
// For example: with a base directory of `/app/assets/javascripts`, the absolute import `/beak/skeleton.js`
// points to the file `/app/assets/javascripts/beak/skeleton.js`.
function absoluteImportBasePlugin(baseDir) {
  return {
    name: "absolute-import-base",
    resolveId: function(sourcePath, importer) {
      // When `importer` is undefined, the file is an entry file. And we don't want to rewrite paths to entry files.
      // - David D. 7/2021
      if(importer && sourcePath.startsWith("/"))
        return path.join(baseDir, sourcePath);
      // When nothing is returned, Rollup falls back to the default resolution. - David D. 7/2021
    },
  }
}

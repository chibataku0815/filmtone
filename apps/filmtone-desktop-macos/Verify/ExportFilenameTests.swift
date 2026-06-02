import Foundation

func registerExportFilenameTests() {
    let sourceURL = URL(fileURLWithPath: "/Users/chibatakumi/Movies/P1290493.MOV")

    runner.test("export filename uses built-in Look slug instead of reset preset") {
        let filename = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: FilmtonePresetCatalog.defaultName,
            lookSlug: "filmtone-creative-pack-01-stone",
            fileExtension: "mp4"
        )
        try assertEqual(filename, "P1290493-stone.mp4")
    }

    runner.test("export filename keeps preset suffix when no Look is active") {
        let filename = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: "reset",
            lookSlug: nil,
            fileExtension: "mp4"
        )
        try assertEqual(filename, "P1290493-reset.mp4")
    }

    runner.test("export filename applies the same Look suffix to still export formats") {
        let filename = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: "reset",
            lookSlug: "filmtone-creative-pack-01-noir",
            fileExtension: ".png"
        )
        try assertEqual(filename, "P1290493-noir.png")
    }

    runner.test("export filename falls back to sanitized unknown Look slug") {
        let filename = FilmtoneExportFilename.defaultFilename(
            sourceURL: sourceURL,
            presetName: "reset",
            lookSlug: "custom/Look Name",
            fileExtension: "mp4"
        )
        try assertEqual(filename, "P1290493-custom-look-name.mp4")
    }
}

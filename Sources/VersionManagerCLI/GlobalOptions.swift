import ArgumentParser

package struct GlobalOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Path to .appversion.yml")
    package var config: String = ".appversion.yml"

    @Flag(name: .shortAndLong, help: "Verbose logging")
    package var verbose = false

    package init() {}
}

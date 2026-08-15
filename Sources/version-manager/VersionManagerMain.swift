import VersionManagerCLI

@main
struct VersionManagerMain {
    static func main() async {
        await VersionManagerCommand.main()
    }
}

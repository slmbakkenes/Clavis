import Testing

@testable import ClavisCore

@Suite struct ScriptMetadataTests {
  @Test func defaultsComeFromFileName() {
    let metadata = ScriptMetadata.parse(content: "echo hi\n", fileName: "backup.sh")
    #expect(metadata == ScriptMetadata(name: "backup", icon: "💻"))
  }

  @Test func headersOverrideDefaults() {
    let content = """
      #!/bin/zsh
      # name: Back up photos
      # icon: 📸
      rsync -a ~/Pictures /Volumes/Backup
      """
    #expect(
      ScriptMetadata.parse(content: content, fileName: "backup.sh")
        == ScriptMetadata(name: "Back up photos", icon: "📸"))
  }

  @Test func headersAreCaseInsensitiveAndTrimmed() {
    let content = "#NAME:   Deploy   \n#  Icon: 🚀\r\n"
    #expect(
      ScriptMetadata.parse(content: content, fileName: "deploy.sh")
        == ScriptMetadata(name: "Deploy", icon: "🚀"))
  }

  @Test func headerNotAtLineStartIsIgnored() {
    let content = "echo '# name: nope'\n  # icon: 🙃\n"
    #expect(
      ScriptMetadata.parse(content: content, fileName: "run.sh")
        == ScriptMetadata(name: "run", icon: "💻"))
  }

  @Test func firstMatchingHeaderWins() {
    let content = "# name: First\n# name: Second\n"
    #expect(ScriptMetadata.parse(content: content, fileName: "x.sh").name == "First")
  }

  @Test func appleScriptCommentHeadersWork() {
    let content = "# name: Toggle Wi-Fi\ntell application \"System Events\" to beep\n"
    #expect(ScriptMetadata.parse(content: content, fileName: "wifi.applescript").name == "Toggle Wi-Fi")
  }

  @Test func multiDotFileNamesKeepTextBeforeFirstDot() {
    #expect(ScriptMetadata.parse(content: "", fileName: "my.backup.v2.sh").name == "my")
    #expect(ScriptMetadata.parse(content: "", fileName: ".hidden.sh").name == "")
  }

  @Test func onlyShellAndAppleScriptFilesAreScripts() {
    #expect(ScriptMetadata.isScript(fileName: "a.sh"))
    #expect(ScriptMetadata.isScript(fileName: "b.applescript"))
    #expect(!ScriptMetadata.isScript(fileName: "c.py"))
    #expect(!ScriptMetadata.isScript(fileName: "d.scpt"))
    #expect(!ScriptMetadata.isScript(fileName: "e.SH"))
    #expect(!ScriptMetadata.isScript(fileName: "README.md"))
  }
}

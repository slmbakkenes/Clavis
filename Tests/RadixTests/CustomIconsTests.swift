import AppKit
import RadixCore
import Testing

@testable import Radix

@MainActor
@Suite struct CustomIconsTests {
  private func exists(_ name: String) -> Bool {
    NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
  }

  @Test func everyPickerSymbolExists() {
    for name in CustomIcons.pickerSymbols {
      #expect(exists(name), "missing picker symbol \(name)")
    }
    #expect(Set(CustomIcons.pickerSymbols).count == CustomIcons.pickerSymbols.count)
  }

  @Test func everyLegacyMappingExists() {
    for name in CustomIcons.legacyMappedSymbols {
      #expect(exists(name), "missing mapped symbol \(name)")
    }
    #expect(exists(CustomIcons.fallbackSymbol))
    #expect(exists(CustomIcons.defaultSymbol))
  }

  @Test func resolvesLegacyNamesSymbolsAndUnknowns() {
    #expect(CustomIcons.symbolName(for: "Apple") == "apple.logo")
    #expect(CustomIcons.symbolName(for: "Airplane") == "airplane")
    #expect(CustomIcons.symbolName(for: "cart.fill") == "cart.fill")
    #expect(CustomIcons.symbolName(for: "Github") == CustomIcons.fallbackSymbol)
    #expect(CustomIcons.symbolName(for: "definitely.not.a.symbol") == CustomIcons.fallbackSymbol)
    #expect(CustomIcons.symbolName(for: "") == CustomIcons.fallbackSymbol)
  }

  @Test func paletteColoursParse() {
    #expect(CustomIcons.colorPalette.count == 14)
    #expect(CustomIcons.colorPalette.allSatisfy { HexColor($0) != nil })
  }
}

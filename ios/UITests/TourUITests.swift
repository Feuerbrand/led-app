import XCTest

/// Kleine Tour durch die App für das Vorführ-Video (Vorführmodus, ohne echtes Licht).
/// Der Build-Workflow nimmt den Simulator dabei als Video auf.
final class TourUITests: XCTestCase {
    private var app: XCUIApplication!

    func testTour() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-demo", "YES", "-showIntro", "YES", "-tour", "YES", "-screenshotFlow", "aurora"]
        app.launch()

        // Einführung
        pause(4.5)
        tap(button("label CONTAINS 'Los geht'"))
        pause(3.5)
        tap(button("label == 'Weiter'"))
        pause(2)
        drag(any("intro-farbrad"), from: CGVector(dx: 0.85, dy: 0.5), to: CGVector(dx: 0.2, dy: 0.35))
        pause(2)
        tap(button("label == 'Weiter'"))
        pause(4)
        tap(button("label == 'Weiter'"))
        pause(3)
        tap(button("label CONTAINS 'Los geht'"))
        pause(3)

        // Hauptmenü → alle Lichter steuern
        tap(any("alle-steuern"))
        pause(2)

        // Helligkeit ziehen
        drag(any("helligkeit"), from: CGVector(dx: 0.85, dy: 0.5), to: CGVector(dx: 0.3, dy: 0.5))
        pause(1)
        drag(any("helligkeit"), from: CGVector(dx: 0.3, dy: 0.5), to: CGVector(dx: 0.95, dy: 0.5))
        pause(1)

        // Farbe: zuletzt benutzte Farben und Farbrad
        tap(button("label == 'Farbe Türkis'"))
        pause(1.5)
        tap(button("label == 'Farbe Pink'"))
        pause(1.5)
        drag(any("farbrad"), from: CGVector(dx: 0.9, dy: 0.5), to: CGVector(dx: 0.15, dy: 0.45))
        pause(2)

        // Effekte
        tap(any("tab-effects"))
        pause(2)
        tap(button("label == 'Regenbogen'"))
        pause(3)
        tap(button("label == 'Lava'"))
        pause(2.5)
        drag(any("tempo"), from: CGVector(dx: 0.5, dy: 0.75), to: CGVector(dx: 0.9, dy: 0.75))
        pause(2)

        // Szenen
        tap(any("tab-scenes"))
        pause(2)
        tap(button("label == 'Entspannen'"))
        pause(3)
        tap(button("label == 'Aufwachen'"))
        pause(4)

        // Zurück und Einstellungen
        back()
        pause(2)
        tap(any("Einstellungen"))
        pause(2)
        tap(any("Hilfe und Protokoll"))
        pause(3)
        back()
        pause(1)
        back()
        pause(2.5)
    }

    // MARK: - Helfer

    private func button(_ format: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: format)).firstMatch
    }

    private func any(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tap(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 10) {
            element.tap()
        } else {
            XCTFail("Nicht gefunden: \(element)")
        }
    }

    private func drag(_ element: XCUIElement, from: CGVector, to: CGVector) {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Nicht gefunden: \(element)")
            return
        }
        let start = element.coordinate(withNormalizedOffset: from)
        let end = element.coordinate(withNormalizedOffset: to)
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    private func back() {
        let bar = app.navigationBars.firstMatch
        if bar.waitForExistence(timeout: 5) {
            bar.buttons.element(boundBy: 0).tap()
        }
    }
}

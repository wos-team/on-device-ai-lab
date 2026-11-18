import XCTest

final class DemoNavigationTests: XCTestCase {
    @MainActor
    func testDemoNavigationAndAudioLifecycle() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Apple機能ラボ"].waitForExistence(timeout: 10))
        open("ローカルLLM基本機能", in: app)
        open("文章生成", in: app)
        checkGuide("Foundation Models · LanguageModelSession", in: app)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        for name in ["顔を3Dの点群で見る", "空中に絵を描く", "拍手で花火",
                     "机にロボットを置く", "体でロボットを動かす", "まばたきゲーム",
                     "ビー玉の手触り", "耳でたどる迷路", "近くの端末へライブ映像", "iPhoneで宝探し"] {
            open(name, in: app)
            if name == "空中に絵を描く" {
                checkGuide("Vision · VNDetectHumanHandPoseRequest", in: app)
            }
            if name == "ビー玉の手触り" {
                app.buttons["弱い衝突"].tap()
                app.buttons["強い衝突"].tap()
            }
            if name == "耳でたどる迷路" {
                app.buttons["迷路を開始"].tap()
                XCTAssertTrue(app.buttons["音を停止"].waitForExistence(timeout: 5))
                // Route around the wall to the sound source.
                for step in ["右", "右", "上", "上", "上", "左", "左"] {
                    app.buttons[step].tap()
                }
                XCTAssertTrue(app.staticTexts["ゴール！ 音源にたどり着きました。"].exists)
            }
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    @MainActor
    func testMicrophoneCanStartStopAndRestart() {
        let app = XCUIApplication()
        app.launch()
        open("拍手で花火", in: app)

        for _ in 0..<3 {
            app.buttons["マイクをオン"].tap()
            let listening = app.staticTexts["聞き取り中 · 拍手か笑い声を試してください"]
            XCTAssertTrue(listening.waitForExistence(timeout: 10))
            // Keep the tap running so callbacks arrive from the audio thread.
            let until = Date().addingTimeInterval(3)
            while Date() < until {
                XCTAssertEqual(app.state, .runningForeground)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            XCTAssertTrue(app.buttons["停止"].exists)
            app.buttons["停止"].tap()
            XCTAssertTrue(app.buttons["マイクをオン"].waitForExistence(timeout: 5))
        }
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Apple機能ラボ"].exists)
    }

    @MainActor
    private func checkGuide(_ technology: String, in app: XCUIApplication) {
        app.buttons["技術と応用を見る"].tap()
        XCTAssertTrue(app.staticTexts[technology].waitForExistence(timeout: 5))
        let references = app.staticTexts["Apple公式資料"]
        for _ in 0..<5 {
            if references.exists && references.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(references.exists)
        XCTAssertTrue(references.isHittable)
        app.buttons["閉じる"].tap()
    }

    @MainActor
    private func open(_ title: String, in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<7 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.exists, title)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), title)
    }
}

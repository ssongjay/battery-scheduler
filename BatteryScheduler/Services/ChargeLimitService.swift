import Foundation

/// macOS 시스템 설정의 Charge Limit 슬라이더를 AppleScript(Accessibility API)로 제어
actor ChargeLimitService {

    enum ChargeLimitError: Error, LocalizedError {
        case scriptFailed(String)
        case invalidLimit(Int)
        case systemSettingsUnavailable

        var errorDescription: String? {
            switch self {
            case .scriptFailed(let msg): return "AppleScript 실행 실패: \(msg)"
            case .invalidLimit(let v): return "유효하지 않은 한도: \(v)% (80~100, 5단위)"
            case .systemSettingsUnavailable: return "시스템 설정을 열 수 없습니다"
            }
        }
    }

    /// 현재 Charge Limit 읽기 (pmset -g battlimit 파싱)
    func currentLimit() -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "battlimit"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if output.contains("No battery level limits set") {
            return 100
        }

        // chargeSocLimitSoc = 80 파싱
        if let range = output.range(of: #"chargeSocLimitSoc\s*=\s*(\d+)"#, options: .regularExpression),
           let numRange = output[range].range(of: #"\d+$"#, options: .regularExpression) {
            return Int(output[numRange])
        }
        return nil
    }

    /// Charge Limit 설정 (AppleScript로 시스템 설정 UI 조작)
    func setLimit(_ percent: Int) async throws {
        guard [80, 85, 90, 95, 100].contains(percent) else {
            throw ChargeLimitError.invalidLimit(percent)
        }

        // pmset에서 읽은 값이 이미 target이면 스킵
        if let current = currentLimit(), current == percent { return }

        let script = buildSetLimitScript(to: percent)
        try await runAppleScript(script)
    }

    // MARK: - Private

    /// 슬라이더의 실제 값을 런타임에 읽어서 target까지 조작하는 스크립트
    private func buildSetLimitScript(to target: Int) -> String {
        let needsAlertHandling = target == 100

        return """
        -- 시스템 설정을 완전히 종료하고 새로 시작 (모달 에러 방지)
        tell application "System Settings" to quit
        delay 1.5
        do shell script "killall 'System Settings' 2>/dev/null || true"
        delay 1

        tell application "System Settings"
            activate
            delay 1.5
            reveal pane id "com.apple.Battery-Settings.extension*BatteryPreferences"
            delay 3
        end tell

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 0.5

                -- "충전" 텍스트 옆 (i) 버튼 찾기
                set elems to entire contents of window 1
                set infoBtn to missing value
                set idx to 0
                repeat with e in elems
                    set idx to idx + 1
                    try
                        if class of e is static text and value of e is "충전" then
                            set infoBtn to item (idx + 1) of elems
                            exit repeat
                        end if
                    end try
                end repeat

                if infoBtn is missing value then error "info button not found"
                click infoBtn
                delay 2

                -- 슬라이더 찾기 (sheet 1 안에 있음)
                set theSlider to missing value
                try
                    set sheetElems to entire contents of sheet 1 of window 1
                    repeat with e in sheetElems
                        try
                            if class of e is slider then
                                set theSlider to e
                                exit repeat
                            end if
                        end try
                    end repeat
                end try

                if theSlider is missing value then error "slider not found in sheet"

                -- 슬라이더의 실제 현재값 읽기
                set curVal to value of theSlider as integer
                set targetVal to \(target)

                if curVal is equal to targetVal then
                    -- 이미 목표값
                else if \(needsAlertHandling ? "true" : "false") then
                    -- 100%로 설정: 먼저 95까지 올리고 알럿 처리
                    repeat while (value of theSlider as integer) < 95
                        perform action "AXIncrement" of theSlider
                        delay 0.4
                    end repeat
                    delay 0.3

                    -- 마지막 increment (알럿 발생)
                    perform action "AXIncrement" of theSlider
                    delay 2

                    -- 알럿에서 "100%로 한도 설정" 클릭
                    -- 알럿은 sheet 안의 sheet (nested)
                    set alertHandled to false

                    -- 방법 1: sheet 1 of sheet 1 of window 1 (nested sheet)
                    try
                        set alertElems to entire contents of sheet 1 of sheet 1 of window 1
                        repeat with e in alertElems
                            try
                                if class of e is button and description of e contains "100" then
                                    click e
                                    set alertHandled to true
                                    exit repeat
                                end if
                            end try
                        end repeat
                    end try

                    -- 방법 2: sheet 1 of window 1 전체에서 찾기
                    if not alertHandled then
                        try
                            set sheetElems to entire contents of sheet 1 of window 1
                            repeat with e in sheetElems
                                try
                                    if class of e is button and description of e contains "100" then
                                        click e
                                        set alertHandled to true
                                        exit repeat
                                    end if
                                end try
                            end repeat
                        end try
                    end if

                    -- 방법 3: window 전체에서 찾기
                    if not alertHandled then
                        set allElems to entire contents of window 1
                        repeat with e in allElems
                            try
                                if class of e is button and description of e contains "100" then
                                    click e
                                    exit repeat
                                end if
                            end try
                        end repeat
                    end if
                    delay 1
                else if targetVal > curVal then
                    -- 올리기
                    repeat while (value of theSlider as integer) < targetVal
                        perform action "AXIncrement" of theSlider
                        delay 0.4
                    end repeat
                else
                    -- 내리기
                    repeat while (value of theSlider as integer) > targetVal
                        perform action "AXDecrement" of theSlider
                        delay 0.4
                    end repeat
                end if

                delay 0.5
            end tell
        end tell

        tell application "System Settings" to quit
        """
    }

    private func runAppleScript(_ source: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        let errPipe = Pipe()
        task.standardError = errPipe
        task.standardOutput = Pipe()

        do {
            try task.run()
        } catch {
            throw ChargeLimitError.scriptFailed(error.localizedDescription)
        }

        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ChargeLimitError.scriptFailed(errOutput)
        }
    }
}

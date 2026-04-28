import Foundation
import Darwin
import ObjectiveC.runtime

/// macOS Charge Limit을 PowerUI private API로 제어하고, 실패 시 Shortcuts/AppleScript로 대체
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

        if try setLimitWithPowerUI(percent) {
            return
        }

        if try await setLimitWithShortcutIfAvailable(percent) {
            return
        }

        let script = buildSetLimitScript(to: percent)
        var lastFailure: Error?

        for attempt in 1...2 {
            do {
                try await runAppleScript(script)
                if let verified = currentLimit(), verified == percent {
                    return
                }
                lastFailure = ChargeLimitError.scriptFailed("설정 후 검증 실패: 목표 \(percent)%, 현재 \(currentLimit().map { "\($0)%" } ?? "읽기 실패")")
            } catch {
                lastFailure = error
            }

            if attempt < 2 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw lastFailure ?? ChargeLimitError.scriptFailed("설정 후 검증 실패")
    }

    // MARK: - Private

    private func setLimitWithPowerUI(_ percent: Int) throws -> Bool {
        guard let client = PowerUIChargeLimitClient() else {
            return false
        }

        guard client.isManualChargeLimitSupported() else {
            return false
        }

        guard client.enableManualChargeLimit() else {
            throw ChargeLimitError.scriptFailed("PowerUI MCL 활성화 실패")
        }

        guard client.setManualChargeLimit(UInt8(percent)) else {
            throw ChargeLimitError.scriptFailed("PowerUI MCL 설정 실패: \(percent)%")
        }

        let verified = client.currentManualChargeLimit()
        guard Int(verified) == percent else {
            throw ChargeLimitError.scriptFailed("PowerUI 설정 후 검증 실패: 목표 \(percent)%, 현재 \(verified)%")
        }

        return true
    }

    private func setLimitWithShortcutIfAvailable(_ percent: Int) async throws -> Bool {
        let name = shortcutName(for: percent)
        guard shortcutExists(named: name) else {
            return false
        }

        try await runShortcut(named: name)

        if let verified = currentLimit(), verified == percent {
            return true
        }

        throw ChargeLimitError.scriptFailed("Shortcuts 실행 후 검증 실패: 목표 \(percent)%, 현재 \(currentLimit().map { "\($0)%" } ?? "읽기 실패")")
    }

    private func shortcutName(for percent: Int) -> String {
        "BatteryScheduler Set \(percent)"
    }

    private func shortcutExists(named name: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["list"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return false
        }

        guard task.terminationStatus == 0 else {
            return false
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output
            .split(whereSeparator: \.isNewline)
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == name }
    }

    private func runShortcut(named name: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]

        let errPipe = Pipe()
        task.standardError = errPipe
        task.standardOutput = Pipe()

        do {
            try task.run()
        } catch {
            throw ChargeLimitError.scriptFailed("Shortcuts 실행 실패: \(error.localizedDescription)")
        }

        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ChargeLimitError.scriptFailed("Shortcuts 실행 실패: \(errOutput)")
        }
    }

    /// 슬라이더의 실제 값을 런타임에 읽어서 target까지 조작하는 스크립트
    private func buildSetLimitScript(to target: Int) -> String {
        let needsAlertHandling = target == 100

        return """
        on waitForSystemSettingsWindow(timeoutSeconds)
            repeat with i from 1 to (timeoutSeconds * 2)
                tell application "System Events"
                    if exists process "System Settings" then
                        tell process "System Settings"
                            if exists window 1 then return true
                        end tell
                    end if
                end tell
                delay 0.5
            end repeat
            return false
        end waitForSystemSettingsWindow

        on findFirstSliderIn(theContainer)
            try
                set theElems to entire contents of theContainer
                repeat with e in theElems
                    try
                        if class of e is slider then return e
                    end try
                end repeat
            end try
            return missing value
        end findFirstSliderIn

        on findChargeInfoButton()
            tell application "System Events"
                tell process "System Settings"
                    set elems to entire contents of window 1
                    set labelHints to {"충전", "Charge", "Charging", "Battery", "배터리"}

                    repeat with idx from 1 to count of elems
                        set e to item idx of elems
                        try
                            if class of e is static text then
                                set labelValue to value of e as text
                                repeat with hint in labelHints
                                    if labelValue contains (hint as text) then
                                        repeat with nextIdx from (idx + 1) to (idx + 8)
                                            if nextIdx <= (count of elems) then
                                                set candidate to item nextIdx of elems
                                                try
                                                    if class of candidate is button then return candidate
                                                end try
                                            end if
                                        end repeat
                                    end if
                                end repeat
                            end if
                        end try
                    end repeat

                    repeat with e in elems
                        try
                            if class of e is button then
                                set buttonDescription to description of e as text
                                if buttonDescription contains "정보" or buttonDescription contains "Info" or buttonDescription contains "Details" then return e
                            end if
                        end try
                    end repeat
                end tell
            end tell
            return missing value
        end findChargeInfoButton

        on findChargeSlider()
            tell application "System Events"
                tell process "System Settings"
                    set theSlider to missing value

                    try
                        set theSlider to my findFirstSliderIn(sheet 1 of sheet 1 of window 1)
                    end try
                    if theSlider is not missing value then return theSlider

                    try
                        set theSlider to my findFirstSliderIn(sheet 1 of window 1)
                    end try
                    if theSlider is not missing value then return theSlider

                    try
                        set theSlider to my findFirstSliderIn(window 1)
                    end try
                    return theSlider
                end tell
            end tell
        end findChargeSlider

        on click100PercentConfirmation()
            tell application "System Events"
                tell process "System Settings"
                    set containersToSearch to {}

                    try
                        set end of containersToSearch to sheet 1 of sheet 1 of window 1
                    end try
                    try
                        set end of containersToSearch to sheet 1 of window 1
                    end try
                    try
                        set end of containersToSearch to window 1
                    end try

                    repeat with containerToSearch in containersToSearch
                        try
                            set alertElems to entire contents of containerToSearch
                            repeat with e in alertElems
                                try
                                    if class of e is button then
                                        set buttonDescription to description of e as text
                                        set buttonName to name of e as text
                                        if buttonDescription contains "100" or buttonName contains "100" then
                                            click e
                                            return true
                                        end if
                                    end if
                                end try
                            end repeat
                        end try
                    end repeat
                end tell
            end tell
            return false
        end click100PercentConfirmation

        on moveSliderToTarget(theSlider, targetVal)
            repeat with stepIndex from 1 to 8
                set curVal to value of theSlider as integer
                if curVal is equal to targetVal then exit repeat
                if curVal < targetVal then
                    perform action "AXIncrement" of theSlider
                else
                    perform action "AXDecrement" of theSlider
                end if
                delay 0.4
            end repeat

            if (value of theSlider as integer) is not equal to targetVal then
                error "slider did not reach target"
            end if
        end moveSliderToTarget

        -- 시스템 설정을 완전히 종료하고 새로 시작 (모달 에러 방지)
        tell application "System Settings" to quit
        delay 1.5
        do shell script "killall 'System Settings' 2>/dev/null || true"
        delay 1

        tell application "System Settings"
            activate
            delay 1.5
            reveal pane id "com.apple.Battery-Settings.extension*BatteryPreferences"
        end tell

        if not my waitForSystemSettingsWindow(10) then error "system settings window not found"
        delay 2

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 0.5

                -- 언어별 텍스트와 정보 버튼 설명을 모두 시도
                set infoBtn to my findChargeInfoButton()
                if infoBtn is missing value then error "info button not found"
                click infoBtn
                delay 1

                -- 슬라이더는 sheet 계층이 OS 버전에 따라 달라질 수 있어 여러 위치를 재시도
                set theSlider to missing value
                repeat with i from 1 to 10
                    set theSlider to my findChargeSlider()
                    if theSlider is not missing value then exit repeat
                    delay 0.5
                end repeat

                if theSlider is missing value then error "slider not found in sheet"

                -- 슬라이더의 실제 현재값 읽기
                set curVal to value of theSlider as integer
                set targetVal to \(target)

                if curVal is equal to targetVal then
                    -- 이미 목표값
                else if \(needsAlertHandling ? "true" : "false") then
                    -- 100%로 설정: 먼저 95까지 올리고 알럿 처리
                    repeat with stepIndex from 1 to 4
                        if (value of theSlider as integer) >= 95 then exit repeat
                        perform action "AXIncrement" of theSlider
                        delay 0.4
                    end repeat
                    if (value of theSlider as integer) < 95 then error "slider did not reach 95 before 100% confirmation"
                    delay 0.3

                    -- 마지막 increment (알럿 발생)
                    perform action "AXIncrement" of theSlider
                    delay 2

                    -- 알럿에서 "100%로 한도 설정" 클릭
                    set alertHandled to my click100PercentConfirmation()
                    if not alertHandled then error "100% confirmation button not found"
                    delay 1
                else if targetVal > curVal then
                    -- 올리기
                    my moveSliderToTarget(theSlider, targetVal)
                else
                    -- 내리기
                    my moveSliderToTarget(theSlider, targetVal)
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

/// Thin wrapper around macOS 26.4's private PowerUI manual charge limit client.
///
/// This is the same backend System Settings uses for the Charge Limit slider.
/// It avoids UI automation, but it is private API and may need revision if
/// Apple changes PowerUI in a future macOS release.
private final class PowerUIChargeLimitClient {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI"
    private static let className = "PowerUISmartChargeClient"

    private let client: AnyObject
    private let clientClass: AnyClass

    init?() {
        _ = dlopen(Self.frameworkPath, RTLD_NOW | RTLD_GLOBAL)

        guard let clientClass = NSClassFromString(Self.className) as? NSObject.Type,
              let allocated = clientClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let initialized = allocated.perform(
                NSSelectorFromString("initWithClientName:"),
                with: "BatteryScheduler" as NSString
              )?.takeUnretainedValue() else {
            return nil
        }

        self.client = initialized
        self.clientClass = clientClass
    }

    func isManualChargeLimitSupported() -> Bool {
        callBool(selectorName: "isMCLSupported")
    }

    func enableManualChargeLimit() -> Bool {
        callBoolWithErrorPointer(selectorName: "enableMCL:")
    }

    func setManualChargeLimit(_ percent: UInt8) -> Bool {
        let selector = NSSelectorFromString("setMCLLimit:error:")
        guard let method = class_getInstanceMethod(clientClass, selector) else {
            return false
        }

        typealias Function = @convention(c) (AnyObject, Selector, UInt8, UnsafeMutableRawPointer?) -> Bool
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return function(client, selector, percent, nil)
    }

    func currentManualChargeLimit() -> UInt8 {
        let selector = NSSelectorFromString("getMCLLimitWithError:")
        guard let method = class_getInstanceMethod(clientClass, selector) else {
            return 0
        }

        typealias Function = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?) -> UInt8
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return function(client, selector, nil)
    }

    private func callBool(selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getInstanceMethod(clientClass, selector) else {
            return false
        }

        typealias Function = @convention(c) (AnyObject, Selector) -> Bool
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return function(client, selector)
    }

    private func callBoolWithErrorPointer(selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getInstanceMethod(clientClass, selector) else {
            return false
        }

        typealias Function = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer?) -> Bool
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        return function(client, selector, nil)
    }
}

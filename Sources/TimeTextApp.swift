import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct TimeTextApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 940, minHeight: 650)
        }
        .windowResizability(.contentSize)
    }
}

struct MainView: View {
    @State private var selectedFiles: [URL] = []
    @State private var focusedFile: URL?
    @State private var isWorking = false
    @State private var status = "Добавьте файлы для начала"
    @State private var progress = false
    @State private var selectedFormat = "TXT"
    @State private var language = "Русский"
    @State private var selectedEngine = "GigaAM"
    @State private var includeTranscript = true
    @State private var includeSummary = true
    @State private var process: Process?
    @State private var resultFiles: [URL] = []
    @State private var errorMessage: String?
    @AppStorage("timetext.exportFolder") private var outputFolderPath = ""

    private let accepted: Set<String> = ["mp4", "mov", "m4v", "mkv", "webm", "avi", "mpeg", "mpg", "wmv", "flv", "mp3", "wav", "m4a", "aac", "flac", "ogg", "opus"]
    private let ink = Color(red: 0.07, green: 0.17, blue: 0.23)
    private let paper = Color(red: 0.96, green: 0.975, blue: 0.98)
    private let sea = Color(red: 0.19, green: 0.68, blue: 0.59)
    private let amber = Color(red: 0.91, green: 0.65, blue: 0.31)

    var body: some View {
        HStack(spacing: 0) {
            queuePanel
                .frame(width: 320)
                .background(ink)
            Rectangle().fill(ink.opacity(0.12)).frame(width: 1)
            exportPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(paper)
        }
        .background(paper)
        .preferredColorScheme(.light)
        .alert("Не удалось расшифровать", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Закрыть", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 42, height: 42)
                    .background(sea, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TimeText").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Локальная расшифровка").font(.system(size: 11)).foregroundStyle(.white.opacity(0.62))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 20)

            Rectangle().fill(.white.opacity(0.13)).frame(height: 1).padding(.horizontal, 22)

            HStack(alignment: .firstTextBaseline) {
                Text("Материалы").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("\(selectedFiles.count)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                    .padding(.horizontal, 9).padding(.vertical, 4).background(sea, in: Capsule())
            }
            .padding(.horizontal, 22).padding(.top, 21).padding(.bottom, 14)

            Button(action: chooseFiles) {
                Label("Добавить файлы", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain).foregroundStyle(.white).disabled(isWorking)
            .padding(.horizontal, 22).padding(.bottom, 12)

            if selectedFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(sea)
                    Text("Перетащите сюда\nвидео или аудио")
                        .font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.86))
                    Text("MP4 · MOV · MP3 · WAV и другие")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.035)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: acceptDrop)
                .padding(.horizontal, 22).padding(.top, 4)
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(selectedFiles, id: \.self) { file in
                            HStack(spacing: 9) {
                                Image(systemName: file.pathExtension.lowercased().contains("mp") ? "waveform" : "film")
                                    .font(.system(size: 14)).foregroundStyle(focusedFile == file ? sea : .white.opacity(0.54))
                                    .frame(width: 22)
                                Button { focusedFile = file } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(file.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundStyle(.white)
                                        Text(file.pathExtension.uppercased())
                                            .font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.48))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button { removeFile(file) } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.48)).padding(6)
                                }
                                .buttonStyle(.plain).disabled(isWorking).help("Убрать из очереди")
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(focusedFile == file ? .white.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: acceptDrop)
            }

            Spacer(minLength: 16)
            Rectangle().fill(.white.opacity(0.13)).frame(height: 1).padding(.horizontal, 22)
            HStack(spacing: 8) {
                Circle().fill(sea).frame(width: 7, height: 7)
                Text("Модели включены · работает офлайн")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
        }
        .frame(maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: acceptDrop)
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Подготовить результат")
                        .font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(ink)
                    Text("Расшифровка и короткая выжимка — на этом Mac")
                        .font(.system(size: 12)).foregroundStyle(ink.opacity(0.62))
                }
                Spacer()
                waveformMark
            }
            .padding(.bottom, 23)

            sectionTitle("Папка сохранения", icon: "folder")
            HStack(spacing: 10) {
                Image(systemName: outputFolderPath.isEmpty ? "arrow.turn.down.right" : "folder.fill")
                    .font(.system(size: 13)).foregroundStyle(sea)
                VStack(alignment: .leading, spacing: 3) {
                    Text(outputFolderPath.isEmpty ? "Рядом с исходными файлами" : URL(fileURLWithPath: outputFolderPath).lastPathComponent)
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                    Text(outputFolderPath.isEmpty ? "Каждый результат сохранится у своего файла" : outputFolderPath)
                        .font(.system(size: 10)).foregroundStyle(ink.opacity(0.56)).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 4)
                Button("Выбрать папку…", action: chooseOutputFolder)
                    .buttonStyle(.bordered).controlSize(.small)
                if !outputFolderPath.isEmpty {
                    Button { outputFolderPath = "" } label: { Image(systemName: "arrow.uturn.backward") }
                        .buttonStyle(.bordered).controlSize(.small).help("Сохранять рядом с исходными файлами")
                }
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.09), lineWidth: 1))

            sectionTitle("Что сохранить", icon: "square.and.arrow.down", top: 22)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Toggle("Расшифровка с таймкодами", isOn: $includeTranscript).toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .medium)).disabled(isWorking)
                    Spacer()
                    if includeTranscript {
                        Picker("Формат расшифровки", selection: $selectedFormat) {
                            Text("TXT").tag("TXT")
                            Text("Word").tag("DOCX")
                        }
                        .labelsHidden().frame(width: 90).controlSize(.small).disabled(isWorking)
                    }
                }
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1).padding(.vertical, 11)
                HStack(spacing: 10) {
                    Toggle("Краткая выжимка", isOn: $includeSummary).toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .medium)).disabled(isWorking)
                    Spacer()
                    Text("отдельный TXT-файл")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(ink.opacity(0.52))
                }
            }
            .padding(13)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.09), lineWidth: 1))

            sectionTitle("Распознавание", icon: "waveform", top: 22)
            HStack(spacing: 14) {
                Picker("Движок", selection: $selectedEngine) {
                    Text("GigaAM · русский").tag("GigaAM")
                    Text("Whisper · разные языки").tag("Whisper")
                }
                .frame(width: 190).disabled(isWorking)
                if selectedEngine == "Whisper" {
                    Picker("Язык", selection: $language) {
                        Text("Русский").tag("Русский")
                        Text("Автоопределение").tag("Авто")
                    }
                    .frame(width: 150).disabled(isWorking)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 18)

            if !resultFiles.isEmpty {
                Rectangle().fill(ink.opacity(0.12)).frame(height: 1).padding(.bottom, 13)
                HStack {
                    Text("Готовые файлы").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                    Spacer()
                    Button("Показать в Finder") { NSWorkspace.shared.activateFileViewerSelecting(resultFiles) }
                        .font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(sea)
                }.padding(.bottom, 8)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(resultFiles, id: \.self) { file in
                            Button { NSWorkspace.shared.open(file) } label: {
                                Label(file.lastPathComponent, systemImage: file.pathExtension.lowercased() == "docx" ? "doc.richtext" : "doc.text")
                                    .font(.system(size: 10, weight: .medium)).lineLimit(1)
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(.white, in: Capsule())
                                    .overlay(Capsule().stroke(ink.opacity(0.10), lineWidth: 1))
                            }.buttonStyle(.plain).foregroundStyle(ink).help("Открыть \(file.lastPathComponent)")
                        }
                    }
                }.frame(height: 34)
            }

            HStack(spacing: 10) {
                if progress { ProgressView().controlSize(.small).tint(sea) }
                Text(status).font(.system(size: 11, weight: .medium)).foregroundStyle(ink.opacity(0.63)).lineLimit(2)
                Spacer(minLength: 8)
                if isWorking {
                    Button("Отменить") { cancel() }.buttonStyle(.bordered).controlSize(.regular)
                } else {
                    Button(action: transcribe) {
                        Label("Обработать \(selectedFiles.count)", systemImage: "waveform.and.mic")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent).tint(sea).controlSize(.large)
                    .disabled(selectedFiles.isEmpty || (!includeTranscript && !includeSummary))
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 28).padding(.top, 27).padding(.bottom, 22)
    }

    private var waveformMark: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array([9.0, 17, 25, 13, 21, 29, 15, 23, 11, 19, 8].enumerated()), id: \.offset) { index, height in
                Capsule().fill(index == 5 ? amber : sea.opacity(index % 3 == 0 ? 0.45 : 0.85))
                    .frame(width: 3, height: height)
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }

    private func sectionTitle(_ title: String, icon: String, top: CGFloat = 0) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(sea)
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(ink)
        }
        .padding(.top, top).padding(.bottom, 9)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .audio, .mpeg4Movie, .quickTimeMovie]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Добавить"
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Куда сохранить результаты"
        panel.prompt = "Выбрать папку"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let folder = panel.url { outputFolderPath = folder.path }
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { addFiles([url]) }
            }
        }
        return true
    }

    private func addFiles(_ urls: [URL]) {
        let valid = urls.filter { accepted.contains($0.pathExtension.lowercased()) }
        selectedFiles = Array((selectedFiles + valid).reduce(into: [URL]()) { if !$0.contains($1) { $0.append($1) } })
        if focusedFile == nil { focusedFile = valid.first }
        status = valid.count != urls.count ? "Добавлены подходящие файлы; неподдерживаемые пропущены" : "Файлов в очереди: \(selectedFiles.count)"
    }

    private func removeFile(_ file: URL) {
        selectedFiles.removeAll { $0 == file }
        if focusedFile == file { focusedFile = selectedFiles.first }
        status = selectedFiles.isEmpty ? "Добавьте файлы для начала" : "Файлов в очереди: \(selectedFiles.count)"
    }

    private func transcribe() {
        guard !selectedFiles.isEmpty, includeTranscript || includeSummary else { return }
        isWorking = true; progress = true; resultFiles = []
        let files = selectedFiles
        let format = selectedFormat
        let engine = selectedEngine
        let saveTranscript = includeTranscript
        let makeSummary = includeSummary
        let chosenFolder = outputFolderPath
        let lang = language == "Русский" ? "ru" : "auto"
        status = "Подготовка аудио…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var outputs: [URL] = []
                var summaryFailed = false
                for (index, input) in files.enumerated() {
                    DispatchQueue.main.async {
                        status = "Файл \(index + 1) из \(files.count): распознавание…"
                    }
                    let output = try Self.runTranscription(input: input, language: lang, engine: engine, app: Bundle.main.bundleURL) { proc in
                        DispatchQueue.main.async { process = proc }
                    }
                    let destinationDirectory = chosenFolder.isEmpty ? input.deletingLastPathComponent() : URL(fileURLWithPath: chosenFolder, isDirectory: true)
                    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                    let baseName = input.deletingPathExtension().lastPathComponent
                    if saveTranscript {
                        let ext = format == "TXT" ? "txt" : "docx"
                        let transcriptURL = Self.uniqueOutputURL(directory: destinationDirectory, baseName: baseName, extension: ext)
                        if format == "TXT" { try output.write(to: transcriptURL, atomically: true, encoding: .utf8) }
                        else { try Self.writeDocx(output, to: transcriptURL) }
                        outputs.append(transcriptURL)
                    }
                    if makeSummary {
                        DispatchQueue.main.async { status = "Файл \(index + 1) из \(files.count): создаю отдельную выжимку…" }
                        do {
                            let summary = try Self.makeSummary(output, app: Bundle.main.bundleURL) { proc in
                                DispatchQueue.main.async { process = proc }
                            }
                            let summaryURL = Self.uniqueOutputURL(directory: destinationDirectory, baseName: "\(baseName)_выжимка", extension: "txt")
                            try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
                            outputs.append(summaryURL)
                        } catch {
                            summaryFailed = true
                        }
                    }
                }
                DispatchQueue.main.async {
                    resultFiles = outputs
                    if summaryFailed { status = outputs.isEmpty ? "Выжимку создать не удалось" : "Файлы готовы; для части записей выжимка не создана" }
                    else { status = "Готово · сохранено файлов: \(outputs.count)" }
                    isWorking = false; progress = false; process = nil
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Не удалось завершить расшифровку"; errorMessage = error.localizedDescription
                    isWorking = false; progress = false; process = nil
                }
            }
        }
    }

    private static func uniqueOutputURL(directory: URL, baseName: String, extension ext: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
        var suffix = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)_\(suffix)").appendingPathExtension(ext)
            suffix += 1
        }
        return candidate
    }

    private func cancel() {
        process?.terminate()
        isWorking = false; progress = false; status = "Операция отменена"
    }

    private static func runTranscription(input: URL, language: String, engine: String, app: URL, onProcess: (Process) -> Void) throws -> String {
        let resources = app.appendingPathComponent("Contents/Resources")
        let bin = resources.appendingPathComponent("bin")
        let ffmpeg = bin.appendingPathComponent("ffmpeg")
        let whisper = bin.appendingPathComponent("whisper-cli")
        let model = resources.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin")
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("TimeText-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let audio = work.appendingPathComponent("audio.wav")
        let base = work.appendingPathComponent("result")

        try execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path, "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", audio.path], onProcess)
        if engine == "GigaAM" {
            let gigaam = resources.appendingPathComponent("GigaAMRuntime/gigaam-transcribe")
            let bundledModel = resources.appendingPathComponent("GigaAM")
            try execute(gigaam, ["--input", audio.path, "--output", base.path + ".srt", "--model-dir", bundledModel.path], onProcess)
            return try parseSRT(at: URL(fileURLWithPath: base.path + ".srt"))
        }
        let langArg = language == "auto" ? "auto" : language
        try execute(whisper, ["-m", model.path, "-f", audio.path, "-l", langArg, "-osrt", "-of", base.path, "-np"], onProcess)
        return try parseSRT(at: URL(fileURLWithPath: base.path + ".srt"))
    }

    private static func parseSRT(at srtURL: URL) throws -> String {
        let srt = try String(contentsOf: srtURL, encoding: .utf8)
        let lines = srt.components(separatedBy: .newlines)
        var result: [String] = []
        var timestamp: String?
        var words: [String] = []
        func flush() {
            guard let timestamp, !words.isEmpty else { return }
            result.append("[\(String(timestamp.prefix(8)))] \(words.joined(separator: " "))")
            words.removeAll()
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains(" --> ") {
                flush(); timestamp = trimmed.components(separatedBy: " --> ").first
            } else if !trimmed.isEmpty && Int(trimmed) == nil {
                words.append(trimmed)
            }
        }
        flush()
        return result.joined(separator: "\n")
    }

    private static func makeSummary(_ transcript: String, app: URL, onProcess: (Process) -> Void) throws -> String {
        let resources = app.appendingPathComponent("Contents/Resources")
        let server = resources.appendingPathComponent("bin/llama-server")
        let model = resources.appendingPathComponent("Qwen3-0.6B-Q8_0.gguf")
        let port = Int.random(in: 49152...65535)
        let process = Process()
        process.executableURL = server
        process.arguments = ["--model", model.path, "--ctx-size", "4096", "--n-gpu-layers", "99", "--host", "127.0.0.1", "--port", String(port), "--parallel", "1", "--alias", "timetext-summary", "--no-webui", "--log-disable"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        onProcess(process)
        try process.run()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() } }

        let base = URL(string: "http://127.0.0.1:\(port)")!
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if !process.isRunning { throw NSError(domain: "TimeText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось запустить локальную модель краткого содержания"]) }
            var request = URLRequest(url: base.appendingPathComponent("health"), timeoutInterval: 2)
            request.httpMethod = "GET"
            if (try? Self.httpData(for: request).1) == 200 { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        guard Date() < deadline else { throw NSError(domain: "TimeText", code: 4, userInfo: [NSLocalizedDescriptionKey: "Локальная модель слишком долго загружалась"]) }

        let chunks = Self.transcriptChunks(transcript, characterLimit: 3500)
        var summaries: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let instruction = "Составь краткое содержание фрагмента русской расшифровки. Выдели только ключевые темы и факты; не добавляй сведений, которых нет в тексте. Если фрагмент неполный или неразборчивый, не додумывай. Ответь по-русски 2–4 короткими предложениями. Не выводи рассуждения. /no_think\n\nФрагмент \(index + 1) из \(chunks.count):\n\(chunk)"
            summaries.append(try Self.requestSummary(instruction, server: base))
        }
        while summaries.count > 1 {
            var next: [String] = []
            for group in stride(from: 0, to: summaries.count, by: 6) {
                let part = Array(summaries[group..<min(group + 6, summaries.count)])
                let instruction = "Сведи заметки по одной расшифровке в единое краткое содержание. Сохрани главные темы, факты, выводы и важные оговорки; не добавляй ничего нового. Пиши по-русски, ясно и компактно, 4–7 предложений. Не выводи рассуждения. /no_think\n\nЗаметки:\n\(part.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))"
                next.append(try Self.requestSummary(instruction, server: base))
            }
            summaries = next
        }
        let result = summaries.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Краткое содержание не сформировано."
        guard !result.isEmpty else { throw NSError(domain: "TimeText", code: 5, userInfo: [NSLocalizedDescriptionKey: "Модель вернула пустое краткое содержание"]) }
        return result
    }

    private static func transcriptChunks(_ text: String, characterLimit: Int) -> [String] {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var chunks: [String] = []
        var current = ""
        for line in lines {
            var remaining = line
            while !remaining.isEmpty {
                let room = max(1, characterLimit - current.count - (current.isEmpty ? 0 : 1))
                let piece = String(remaining.prefix(room))
                if !current.isEmpty && current.count + piece.count + 1 > characterLimit {
                    chunks.append(current); current = ""
                    continue
                }
                current += current.isEmpty ? piece : "\n\(piece)"
                remaining = String(remaining.dropFirst(piece.count))
                if !remaining.isEmpty { chunks.append(current); current = "" }
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }

    private static func requestSummary(_ prompt: String, server: URL) throws -> String {
        var request = URLRequest(url: server.appendingPathComponent("v1/chat/completions"), timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "timetext-summary",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 180,
            "chat_template_kwargs": ["enable_thinking": false]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, status) = try httpData(for: request)
        guard (200..<300).contains(status) else {
            throw NSError(domain: "TimeText", code: status, userInfo: [NSLocalizedDescriptionKey: "Ошибка локальной модели краткого содержания (HTTP \(status))"])
        }
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = response?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else {
            throw NSError(domain: "TimeText", code: 6, userInfo: [NSLocalizedDescriptionKey: "Локальная модель вернула неожиданный ответ"])
        }
        let withoutThoughts = content.replacingOccurrences(of: "(?s)<think>.*?</think>", with: "", options: .regularExpression)
        return withoutThoughts.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func httpData(for request: URLRequest) throws -> (Data, Int) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, Int), Error>!
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { result = .failure(error) }
            else { result = .success((data ?? Data(), (response as? HTTPURLResponse)?.statusCode ?? 0)) }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return try result.get()
    }

    private static func execute(_ url: URL, _ args: [String], _ callback: (Process) -> Void) throws {
        let p = Process(); p.executableURL = url; p.arguments = args
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        callback(p)
        try p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 {
            let data = err.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(domain: "TimeText", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: detail.isEmpty ? "Ошибка обработки медиафайла (код \(p.terminationStatus))" : String(detail.suffix(1200))])
        }
    }

    private static func writeDocx(_ text: String, to destination: URL) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("TimeText-docx-\(UUID().uuidString)", isDirectory: true)
        let root = temp.appendingPathComponent("docx", isDirectory: true)
        let rels = root.appendingPathComponent("_rels", isDirectory: true)
        let word = root.appendingPathComponent("word", isDirectory: true)
        try fm.createDirectory(at: rels, withIntermediateDirectories: true)
        try fm.createDirectory(at: word, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        try "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>".write(to: root.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>".write(to: rels.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            "<w:p><w:r><w:t xml:space=\"preserve\">\(xmlEscape(String(line)))</w:t></w:r></w:p>"
        }.joined()
        let document = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(paragraphs)<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1134\" w:right=\"1134\" w:bottom=\"1134\" w:left=\"1134\"/></w:sectPr></w:body></w:document>"
        try document.write(to: word.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
        try? fm.removeItem(at: destination)
        let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); zip.arguments = ["-qr", destination.path, "."]; zip.currentDirectoryURL = root
        let err = Pipe(); zip.standardError = err
        try zip.run(); zip.waitUntilExit()
        if zip.terminationStatus != 0 { throw NSError(domain: "TimeText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать документ Word"]) }
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
}

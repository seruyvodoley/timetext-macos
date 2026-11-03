import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct TimeTextApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 660, minHeight: 530)
        }
        .windowResizability(.contentSize)
    }
}

struct MainView: View {
    @State private var selectedFiles: [URL] = []
    @State private var isWorking = false
    @State private var status = "Перетащите сюда видео или нажмите «Выбрать видео»"
    @State private var progress = false
    @State private var selectedFormat = "TXT"
    @State private var language = "Русский"
    @State private var selectedEngine = "GigaAM"
    @State private var includeSummary = true
    @State private var process: Process?
    @State private var resultURL: URL?
    @State private var errorMessage: String?

    private let accepted: Set<String> = ["mp4", "mov", "m4v", "mkv", "webm", "avi", "mpeg", "mpg", "wmv", "flv", "mp3", "wav", "m4a", "aac", "flac", "ogg", "opus"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ТаймТекст").font(.system(size: 25, weight: .semibold))
                    Text(selectedEngine == "GigaAM" ? "Русская речь · GigaAM от Сбера · офлайн" : "Мультиязычная расшифровка · Whisper · офлайн")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 31)).foregroundStyle(.secondary)
                Text(selectedFiles.isEmpty ? "Перетащите файл сюда" : selectedFiles.map(\.lastPathComponent).joined(separator: "\n"))
                    .font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center).lineLimit(3)
                Button("Выбрать видео") { chooseFiles() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6])))
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: acceptDrop)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Распознавание").font(.caption).foregroundStyle(.secondary)
                    Picker("Распознавание", selection: $selectedEngine) {
                        Text("GigaAM от Сбера — русский").tag("GigaAM")
                        Text("Whisper — разные языки").tag("Whisper")
                    }.labelsHidden().frame(width: 200)
                }
                if selectedEngine == "Whisper" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Язык речи").font(.caption).foregroundStyle(.secondary)
                        Picker("Язык речи", selection: $language) {
                            Text("Русский").tag("Русский")
                            Text("Определить автоматически").tag("Авто")
                        }.labelsHidden().frame(width: 170)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Формат результата").font(.caption).foregroundStyle(.secondary)
                    Picker("Формат результата", selection: $selectedFormat) {
                        Text("TXT с таймкодами").tag("TXT")
                        Text("Word с таймкодами").tag("DOCX")
                    }.labelsHidden().frame(width: 150)
                }
            }

            Toggle("Добавить краткое содержание (локальная нейросеть)", isOn: $includeSummary)
                .toggleStyle(.checkbox)
            Text("Qwen3 работает на этом Mac; содержание аудио никуда не отправляется.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                if progress { ProgressView().controlSize(.small) }
                Text(status).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                if isWorking {
                    Button("Отменить") { cancel() }.buttonStyle(.bordered)
                } else {
                    Button("Расшифровать") { transcribe() }
                        .buttonStyle(.borderedProminent).disabled(selectedFiles.isEmpty)
                }
            }
            if let resultURL {
                HStack(spacing: 12) {
                    Label("Готово: \(resultURL.lastPathComponent)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).lineLimit(1)
                    Spacer()
                    Button("Открыть") { NSWorkspace.shared.open(resultURL) }
                    Button("Показать в Finder") { NSWorkspace.shared.activateFileViewerSelecting([resultURL]) }
                }.font(.system(size: 12))
            }
            Spacer(minLength: 0)
            Text("Распознавание выполняется на этом Mac. Длинные записи могут обрабатываться несколько минут.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(24)
        .alert("Не удалось расшифровать", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Закрыть", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
        if valid.count != urls.count { status = "Добавлены поддерживаемые файлы; неподдерживаемые пропущены" }
        else { status = selectedFiles.isEmpty ? "Выберите видео или аудиофайл" : "Файлов в очереди: \(selectedFiles.count)" }
        resultURL = nil
    }

    private func transcribe() {
        guard !selectedFiles.isEmpty else { return }
        isWorking = true; progress = true; resultURL = nil
        let files = selectedFiles
        let format = selectedFormat
        let engine = selectedEngine
        let makeSummary = includeSummary
        let lang = language == "Русский" ? "ru" : "auto"
        status = "Подготовка аудио…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var last: URL?
                var summaryFailed = false
                for (index, input) in files.enumerated() {
                    DispatchQueue.main.async {
                        status = "Файл \(index + 1) из \(files.count): подготовка аудио…"
                    }
                    let output = try Self.runTranscription(input: input, language: lang, engine: engine, app: Bundle.main.bundleURL) { proc in
                        DispatchQueue.main.async { process = proc }
                    }
                    var finalOutput = output
                    if makeSummary {
                        DispatchQueue.main.async { status = "Файл \(index + 1) из \(files.count): готовлю краткое содержание локальной нейросетью…" }
                        do {
                            let summary = try Self.makeSummary(output, app: Bundle.main.bundleURL) { proc in
                                DispatchQueue.main.async { process = proc }
                            }
                            finalOutput = "КРАТКОЕ СОДЕРЖАНИЕ\n\(summary)\n\nРАСШИФРОВКА С ТАЙМКОДАМИ\n\(output)"
                        } catch {
                            summaryFailed = true
                        }
                    }
                    let destination = input.deletingPathExtension().appendingPathExtension(format.lowercased() == "txt" ? "txt" : "docx")
                    if format == "TXT" {
                        try finalOutput.write(to: destination, atomically: true, encoding: .utf8)
                    } else {
                        try Self.writeDocx(finalOutput, to: destination)
                    }
                    last = destination
                }
                DispatchQueue.main.async {
                    resultURL = last
                    status = makeSummary ? (summaryFailed ? "Расшифровка готова; краткое содержание создать не удалось" : "Расшифровка и краткое содержание готовы") : "Расшифровка завершена"
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

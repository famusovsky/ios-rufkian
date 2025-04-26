//
//  CallView.swift
//  rufkian
//
//  Created by Aleksei Stepanov on 2025-02-13.
//

import Combine
import SwiftUI
import Speech

struct CallView: View {
    @ObservedObject var speechRec = SpeechHandler()
    @Binding var presentedAsModal: Bool
    @State private var timerString: String?
    @State private var startTime: Date?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Spacer()
            Text(timerString ?? "")
                .onAppear() {
                    timerString = "00:00"
                    startTime = Date()
                }
                .onReceive(timer) { _ in 
                    timerString = Date().passedTime(from: startTime!) 
                }
                .font(Font.system(.largeTitle, design: .monospaced))
            Text("Вы сказали: ")
            Text(speechRec.userInput)
            Spacer()
            Text("ИИ ответил: ")
            Text(speechRec.aiOutput)
            Spacer()
            Button(action: {
                deleteAiCall()
                presentedAsModal = false
            }) {
                Label("Завершить звонок", systemImage: "phone.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
            .buttonBorderShape(.roundedRectangle)
            .tint(.red)
            Spacer()
        }
        .onAppear {
            self.speechRec.start()
        }
        .onDisappear() {
            self.speechRec.stop()
        }
    }
}

class SpeechHandler: ObservableObject {
    @Published private(set) var userInput = ""
    @Published private(set) var aiOutput = ""
    private var recognizedTextTimer: Timer?
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    let speechSynth = AVSpeechSynthesizer()

    private var cancellables = Set<AnyCancellable>()
    init() {
        try! AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        try! AVAudioSession.sharedInstance().setActive(true)

        $userInput
            .sink { [weak self] newText in
                print("new text", newText)
                print("user input", self?.userInput ?? "")
                if self?.userInput != "" {
                    self?.resetTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            self.startRecognition()
        }
    }
    
    func stop() {
        audioEngine.stop()
        stopRecognition()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizedTextTimer = nil
    }
    
    func stopRecognition() {
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognizedTextTimer?.invalidate()
    }
    
    func startRecognition() {
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    self.speechSynth.stopSpeaking(at: .immediate) // TODO possibly must implement continue
                    self.userInput = result.bestTranscription.formattedString
                }
            }

            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                print("Invalid audio format")
                return
            }
            
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("start recognition error")
            // TODO catch error
        }
    }
    
    func restartRecognition() {
        self.userInput = ""
        self.stopRecognition()
        self.startRecognition()
    }
    
    private func resetTimer() {
        recognizedTextTimer?.invalidate()
        recognizedTextTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            if let inputCopy = self?.userInput {
                Task {
                    do {
                        try await getResponse(input: inputCopy) { response in
                            self?.aiOutput = response.answer
                            if response.status == "OK" {
                                let utterance = AVSpeechUtterance(string: response.answer)
                                utterance.pitchMultiplier = 1.0
                                utterance.rate = 0.5
                                utterance.voice = AVSpeechSynthesisVoice(language: "de")
                                
                                self?.speechSynth.speak(utterance)
                            } else {
                                print("got non OK status from telephonist: \(response.status)")
                            }
                        }
                    } catch {
                        print("API call failed: \(error)")
                    }
                }
            }
            self?.restartRecognition()
        }
    }
}

private struct PostRequest: Encodable {
    let input: String
}

private struct PostResponse: Decodable {
    let answer: String
    let status: String
}

private func getResponse(input: String, completionHandler:@escaping (_ response:PostResponse)->Void) async throws -> Void {
    let request = NSMutableURLRequest(url: NSURL(string: "https://telephonist.rufkian.ru")! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    for field in HTTPCookie.requestHeaderFields(with: HTTPCookieStorage.shared.cookies ?? []) {
        request.setValue(field.value, forHTTPHeaderField: field.key)
    }
    request.httpBody = try? JSONEncoder().encode(PostRequest(input: input))

    let session = URLSession.shared
    let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
        if let error = error {
            print(error)
        } else {
            _ = response as? HTTPURLResponse
            // TODO check response status
        }

        var result: PostResponse?
        do {
            result = try JSONDecoder().decode(PostResponse.self, from: data ?? Data())
        } catch {
            print("Failed to convert JSON \(error)")
        }
                
        if let result = result {
            completionHandler(result)
        }
    }

    dataTask.resume()
}


private struct DeleteResponse: Decodable {
    let status: String
}

private func deleteAiCall() -> Void {
    let request = NSMutableURLRequest(url: NSURL(string: "https://telephonist.rufkian.ru")! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for field in HTTPCookie.requestHeaderFields(with: HTTPCookieStorage.shared.cookies ?? []) {
        request.setValue(field.value, forHTTPHeaderField: field.key)
    }
    request.httpMethod = "DELETE"

    let session = URLSession.shared
    let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
        if let error = error {
            print(error)
        } else {
            _ = response as? HTTPURLResponse
            // TODO check response status
        }

        var result: DeleteResponse?
        do {
            result = try JSONDecoder().decode(DeleteResponse.self, from: data ?? Data())
        } catch {
            // TODO actualy do smth
            print("Failed to convert JSON \(error)")
        }
        
        if let result = result {
            // TODO actually do smth
            print(result.status)
        }
    }

    dataTask.resume()
}

extension Date {
    func passedTime(from date: Date) -> String {
        let difference = Calendar.current.dateComponents([.minute, .second], from: date, to: self)
        
        let strMin = String(format: "%02d", difference.minute ?? 00)
        let strSec = String(format: "%02d", difference.second ?? 00)
        
        return "\(strMin):\(strSec)"
    }
}

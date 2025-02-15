//
//  CallView.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-02-13.
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
                .onReceive(timer) { _ in timerString = Date().passedTime(from: startTime!) }
                .font(Font.system(.largeTitle, design: .monospaced))
            
            Text(speechRec.userInput)
            Spacer()
            
            Button(action: { presentedAsModal = false}) {
                Label("End Call", systemImage: "phone.down")
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
    @Published private(set) var userInput = "Hello, what is your name?"
    private var recognizedTextTimer: Timer?
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    let speechSynth = AVSpeechSynthesizer()
    
    private var cancellables = Set<AnyCancellable>()
    init() {
        $userInput
            .sink { [weak self] newText in
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
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognizedTextTimer?.invalidate()
        recognizedTextTimer = nil
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
        }

        catch {
            print("start recognition error")
            // TODO catch error
        }
    }
    
    private func resetTimer() {
        recognizedTextTimer?.invalidate()
        recognizedTextTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            if let inputCopy = self?.userInput {
                Task {
                    do {
                        try await getAiResponse(input: inputCopy, completionHandler: { response in
                            // FIXME it somehow works twice
                            print(response)
                            if response.status == "OK" {
                                let utterance = AVSpeechUtterance(string: response.answer)
                                utterance.pitchMultiplier = 1.0
                                utterance.rate = 0.5
                                utterance.voice = AVSpeechSynthesisVoice(language: "de")
                                
                                self?.speechSynth.speak(utterance)
                            } else {
                                print("got non OK status from telephonist: \(response.status)")
                            }
                        })
                    } catch {
                        print("API call failed: \(error)")
                    }
                }
            }
            self?.userInput = ""
        }
    }
}

struct AiRequest: Encodable {
    let user_id: UInt64
    let key: String
    let input: String
}

struct AiResponse: Decodable {
    let answer: String
    let status: String
}

private func getAiResponse(input: String, completionHandler:@escaping (_ response:AiResponse)->Void) async throws -> Void {
    // TODO change url
    let request = NSMutableURLRequest(url: NSURL(string: "http://127.0.0.1:8080")! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    // TODO input actual user_id and key
    request.httpBody = try? JSONEncoder().encode(AiRequest(user_id: 1, key: "api_key", input: input))

    let session = URLSession.shared
    let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
        if let error = error {
            print(error)
        } else {
            let httpResponse = response as? HTTPURLResponse
            // TODO check response status
        }

        var result: AiResponse?
        do {
            result = try JSONDecoder().decode(AiResponse.self, from: data ?? Data())
        }
        catch {
            // TODO actualy do smth
            print("Failed to convert JSON \(error)")
        }
                
        if let result = result {
            print(result)
            completionHandler(result)
        }
    })

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

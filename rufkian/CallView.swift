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
            
            Button(action: {
                deleteAiCall()
                presentedAsModal = false
            }) {
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
    // TODO make empty
    @Published private(set) var userInput = "Guten Tag, wie geht es dir?"
    private var recognizedTextTimer: Timer?
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    let speechSynth = AVSpeechSynthesizer()
    // TODO move user info somewhere else
    let userInfo: UserInfo
    
    private var cancellables = Set<AnyCancellable>()
    init() {
        self.userInfo = GetUserInfo()
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
        let userInfo = self.userInfo
        recognizedTextTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            if let inputCopy = self?.userInput {
                Task {
                    do {
                        try await getResponse(input: inputCopy, userInfo: userInfo, completionHandler: { response in
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

struct PostRequest: Encodable {
    let user_id: String
    let key: String
    let input: String
}

struct PostResponse: Decodable {
    let answer: String
    let status: String
}

private func getResponse(input: String, userInfo: UserInfo, completionHandler:@escaping (_ response:PostResponse)->Void) async throws -> Void {
    // TODO change url
    let request = NSMutableURLRequest(url: NSURL(string: "http://127.0.0.1:8080")! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    // TODO input actual user_id and key
    request.httpBody = try? JSONEncoder().encode(PostRequest(user_id: userInfo.id!, key: userInfo.key!, input: input))

    let session = URLSession.shared
    let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
        if let error = error {
            print(error)
        } else {
            _ = response as? HTTPURLResponse
            // TODO check response status
        }

        var result: PostResponse?
        do {
            result = try JSONDecoder().decode(PostResponse.self, from: data ?? Data())
        }
        catch {
            // TODO actualy do smth
            print("Failed to convert JSON \(error)")
        }
                
        if let result = result {
            completionHandler(result)
        }
    })

    dataTask.resume()
}

struct DeleteRequest: Encodable {
    let user_id: String
    let key: String
}

struct DeleteResponse: Decodable {
    let status: String
}

private func deleteAiCall() -> Void {
    // TODO move GetUserInfo
    let userInfo = GetUserInfo()
    if userInfo.IsEmpty() {
        return
    }
    
    let request = NSMutableURLRequest(url: NSURL(string: "http://127.0.0.1:8080")! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "DELETE"
    request.httpBody = try? JSONEncoder().encode(DeleteRequest(user_id: userInfo.id!, key: userInfo.key!))

    let session = URLSession.shared
    let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
        if let error = error {
            print(error)
        } else {
            _ = response as? HTTPURLResponse
            // TODO check response status
        }

        var result: DeleteResponse?
        do {
            result = try JSONDecoder().decode(DeleteResponse.self, from: data ?? Data())
        }
        catch {
            // TODO actualy do smth
            print("Failed to convert JSON \(error)")
        }
        if let result = result {
            // TODO actually do smth
            print(result.status)
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

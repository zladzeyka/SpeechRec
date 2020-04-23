//
//  ViewController.swift
//  SpeechRecogniser
//
//  Created by Nadzeya Karaban on 05.02.20.
//  Copyright © 2020 Nadzeya Karaban. All rights reserved.
//

import AVKit
import Speech
import UIKit

class ViewController: UIViewController {
    private let audioEngine = AVAudioEngine()
    private let micOffImage = UIImage(systemName: "mic.circle")
    private let micOnImage = UIImage(systemName: "mic.circle.fill")

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_GB"))
    private var recognitionTask: SFSpeechRecognitionTask?

    @IBOutlet var button: UIImageView!
    @IBOutlet var transcribedText: UITextView!

    var micOn: Bool = false {
        didSet {
            if micOn {
                button.image = micOnImage
                do {
                    self.transcribedText.text = ""
                    try self.startRecording()
                } catch {
                    print("error is \(error.localizedDescription)")
                }
            } else {
                if audioEngine.isRunning {
                    recognitionRequest?.endAudio()
                    audioEngine.stop()
                }
                button.image = micOffImage
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        requestPermissions()

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        button.isUserInteractionEnabled = true
        button.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized
        else {
            print("not authorized")
            return
        }
        let tappedImage = tapGestureRecognizer.view as! UIImageView
        tappedImage.image = micOnImage
        micOn = !micOn
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in

            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized: break
                case .restricted: break
                case .notDetermined: break
                case .denied: break
                @unknown default: break
                }
            }
        }
    }
    

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 9024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true

        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition ?? false {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    let transcribedString = result.transcriptions[0].formattedString
                    self.transcribedText.text = transcribedString
                }
            }
            if error != nil {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }
}

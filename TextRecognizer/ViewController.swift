//
//  ViewController.swift
//  Text Detection Starter Project
//
//  Created by Vaibhav on 3/29/19.
//  Copyright © 2019 Nickelfox. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var session = AVCaptureSession()
    var requests: [VNRequest] = []
    var recognizedWords: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startLiveVideo()
        self.startRecognizingText()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    override func viewDidLayoutSubviews() {
        self.imageView.layer.sublayers?.first?.frame = self.imageView.bounds
    }
    
    private func startLiveVideo() {
        self.session.sessionPreset = AVCaptureSession.Preset.photo
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        let deviceInput = try! AVCaptureDeviceInput(device: device)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        let queue = DispatchQueue.global(qos: .default)
        deviceOutput.setSampleBufferDelegate(self, queue: queue)
        
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        let imageLayer = AVCaptureVideoPreviewLayer(session: self.session)
        imageLayer.frame = imageView.bounds
        self.imageView.layer.addSublayer(imageLayer)
        
        self.session.startRunning()
    }
    
    private func startRecognizingText() {
        let request = VNDetectTextRectanglesRequest(completionHandler: self.recognizedTextHandler)
        request.reportCharacterBoxes = true
        self.requests = [request]
    }
    
    private func recognizedTextHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            print("Ah, no observations"); return
        }
        
        let result = observations.map { $0 as? VNTextObservation }
        self.highlightText(for: result)
    }
    
    private func highlightText(for result: [VNTextObservation?]) {
        var recognizedWord = ""
        if let observations = result as? [VNClassificationObservation],
            let observation = observations.first  {
            recognizedWord = recognizedWord.appending(observation.identifier)
        }
        
        DispatchQueue.main.async {
            self.imageView.layer.sublayers?.removeSubrange(1...)
            
            for region in result {
                guard let rg = region else {
                    continue
                }
                
                self.recognizedWords.append(recognizedWord)
                self.highlightWord(box: rg)
                if let boxes = region?.characterBoxes {
                    for characterBox in boxes {
                        self.highlightLetters(box: characterBox)
                    }
                }
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
}

extension ViewController {
    
    private func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else { return }
        
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX * imageView.frame.size.width
        let yCord = (1 - minY) * imageView.frame.size.height
        let width = (minX - maxX) * imageView.frame.size.width
        let height = (minY - maxY) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        imageView.layer.addSublayer(outline)
    }
    
    private func highlightLetters(box: VNRectangleObservation) {
        let xCord = box.topLeft.x * imageView.frame.size.width
        let yCord = (1 - box.topLeft.y) * imageView.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * imageView.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.blue.cgColor
        
        imageView.layer.addSublayer(outline)
    }
}

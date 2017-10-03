//  Created by Bogdan Djukic on 2017-09-26.
//  Copyright © 2017 Bogdan Djukic. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import SwiftIpfsApi
import SwiftMultihash

class CameraViewController: WebViewViewController,
                            AVCaptureVideoDataOutputSampleBufferDelegate,
                            AVCaptureAudioDataOutputSampleBufferDelegate,
                            IPFSandEthereumConnectionStateDelegate,
                            UITextViewDelegate {
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    let ciContext = CIContext(options:nil)
    
    var isSessionRunning = false
    var isRecording = false
    var writePath: URL?
    
    var recordingTimer: Timer?
    var recordingTimerFlag: Bool = false
    var descriptionTextCleared: Bool = false
    
    var setupResult: SessionSetupResult = .success
    var lastSampleTime: CMTime!
    
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    
    var videoOutput: AVCaptureVideoDataOutput!
    var audioOutput: AVCaptureAudioDataOutput!
    
    var assetWriter: AVAssetWriter!
    var videoWriter: AVAssetWriterInput!
    var audioWriter: AVAssetWriterInput!
    var videoWriterPixelAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var cameraButton: UIBarButtonItem!
    @IBOutlet private weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraButton.isEnabled = false
        recordButton.isEnabled = false
        
        descriptionTextView.layer.cornerRadius = 10.0
        descriptionTextView.delegate = self
        
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            setupResult = .notAuthorized
        }
        
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("AVCam doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                        UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    @objc func recordingTick() {
        if (recordingTimerFlag) {
            self.recordButton.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
            recordingTimerFlag = false
        }
        else {
            self.recordButton.backgroundColor = UIColor(red: 255, green: 0, blue: 0, alpha: 1.0)
            recordingTimerFlag = true
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if (!descriptionTextCleared) {
            descriptionTextView.text = ""
            descriptionTextCleared = true
        }
    }
    
    func clientConnected() {
    }
    
    // MARK: Session Management
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoInput = videoDeviceInput
            }
            else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add audio input
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            self.audioInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(self.audioInput) {
                session.addInput(self.audioInput)
            }
            else {
                print("Could not add audio device input to the session")
            }
        }
        catch {
            print("Could not create audio device input: \(error)")
        }
        
        // Add video raw output
        self.videoOutput = AVCaptureVideoDataOutput()
        if self.session.canAddOutput(self.videoOutput)
        {
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.session.addOutput(self.videoOutput)
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "dispatch queue"))
            
            setVideoOrientation()
        }
        
        // Add audio raw output
        self.audioOutput = AVCaptureAudioDataOutput()
        if self.session.canAddOutput(self.audioOutput)
        {
            self.session.addOutput(self.audioOutput)
            self.audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "dispatch queue"))
        }
        
        do {
            let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            self.writePath = URL.init(fileURLWithPath: documents).appendingPathComponent("recording.mp4", isDirectory: false)
            
            if FileManager.default.fileExists(atPath: (self.writePath?.path)!) {
                do {
                    try FileManager.default.removeItem(at: self.writePath!)
                }
                catch {
                }
            }
            
            self.assetWriter = try AVAssetWriter.init(outputURL: writePath!, fileType: .mp4)
        }
        catch {
        }
        
        self.videoWriter = AVAssetWriterInput.init(mediaType: .video, outputSettings: self.videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mp4))
        
        self.videoWriterPixelAdaptor = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: self.videoWriter, sourcePixelBufferAttributes: nil)
        
        self.audioWriter = AVAssetWriterInput.init(mediaType: .audio, outputSettings: self.audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4) as? [String : Any])
        
        self.videoWriter.expectsMediaDataInRealTime = true
        self.audioWriter.expectsMediaDataInRealTime = true
        
        if (self.assetWriter.canAdd(self.videoWriter)) {
            self.assetWriter.add(self.videoWriter)
        }
        
        if (self.assetWriter.canAdd(self.audioWriter)) {
            self.assetWriter.add(self.audioWriter)
        }
        
        session.commitConfiguration()
    }
    
    // MARK: Device Configuration
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, AVCaptureDevice.DeviceType.builtInDualCamera], mediaType: AVMediaType.video, position: .unspecified)
    
    @IBAction func close(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction private func changeCamera(_ cameraButton: UIButton) {
        cameraButton.isEnabled = false
        recordButton.isEnabled = false
        
        sessionQueue.async { [unowned self] in
            let currentVideoDevice = self.videoInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = AVCaptureDevice.DeviceType.builtInDualCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
            }
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            if let device = devices.filter({ $0.position == preferredPosition && $0.deviceType == preferredDeviceType }).first {
                newVideoDevice = device
            }
            else if let device = devices.filter({ $0.position == preferredPosition }).first {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    self.session.removeInput(self.videoInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: currentVideoDevice)
                        
                        self.session.addInput(videoDeviceInput)
                        self.videoInput = videoDeviceInput
                    }
                    else {
                        self.session.addInput(self.videoInput);
                    }
                    
                    self.setVideoOrientation()
                    self.session.commitConfiguration()
                }
                catch {
                    print("Error occured while creating video device input: \(error)")
                }
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.cameraButton.isEnabled = true
                self.recordButton.isEnabled = true
            }
        }
    }
    
    @IBAction func createReport(_ sender: Any) {
        do {
            let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let writePath = URL.init(fileURLWithPath: documents).appendingPathComponent("recording.mp4", isDirectory: false)
            
            try self.ipfsApi?.add((writePath.path), completionHandler: {(result: [MerkleNode]) in
                self.ipfsHash = b58String(result[0].hash!)
                print("Added file to IPFS with hash: " + self.ipfsHash!)
                
                DispatchQueue.main.async
                    {
                        let argument = "createReport(\"" + self.ipfsHash! + "\",\"" + self.descriptionTextView.text + "\")"
                        
                        self.webView?.evaluateJavaScript(argument, completionHandler: { (result, error) in
                            if error == nil {
                                print("New report submitted.")
                                
                                self.navigationController?.popToRootViewController(animated: true)
                            }
                            else {
                                print("Error occured while executing smart contract.")
                            }
                        })
                }
            })
        }
        catch {
            print("Error occured while adding file to IPFS.")
        }
    }
    
    // MARK: Recording Movies
    
    @IBAction private func toggleMovieRecording(_ recordButton: UIButton) {
        if (assetWriter.status == .unknown) {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: self.lastSampleTime)
            
            isRecording = true
            
            recordingTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.recordingTick)), userInfo: nil, repeats: true)
        }
        else {
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordButton.backgroundColor = UIColor(red: 255, green: 0, blue: 0, alpha: 1.0)
            
            recordButton.isHidden = true
            descriptionTextView.isHidden = false
            descriptionTextView.becomeFirstResponder()
            descriptionTextView.selectedRange = NSRange.init(location: 0, length: 0)
            
            isRecording = false
            
            assetWriter.finishWriting {
                if (self.assetWriter.status == .failed) {
                    print("Error while saving video file.")
                }
                else if (self.assetWriter.status == .completed)
                {
                    self.nextButton.isEnabled = true
                }
            }
        }
        
        cameraButton.isEnabled = !self.isRecording
    }
    
    func setVideoOrientation() {
        let captureConnection = self.videoOutput.connections[0]
        
        captureConnection.videoOrientation = .portrait
        captureConnection.isVideoMirrored = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if (output == self.videoOutput) {
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            var cameraImage = CIImage.init(cvImageBuffer: pixelBuffer!)
            
            let pixelEffect = CIFilter(name: "CIPixellate", withInputParameters: ["inputScale" : 35.0])
            pixelEffect!.setValue(cameraImage, forKey: kCIInputImageKey)
            cameraImage = (pixelEffect?.outputImage)!
            
            let blackAndWhiteEffect = CIFilter(name: "CIPhotoEffectMono")
            blackAndWhiteEffect!.setValue(cameraImage, forKey: kCIInputImageKey)
            cameraImage = (blackAndWhiteEffect?.outputImage)!
            
            let filteredImage = UIImage.init(ciImage: cameraImage)
            
            DispatchQueue.main.async
                {
                    self.imageView.image = filteredImage
                    
                    if (self.isRecording && self.videoWriter.isReadyForMoreMediaData) {
                        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        
                        self.ciContext.render(cameraImage, to: pixelBuffer!)
                        
                        self.videoWriterPixelAdaptor.append(pixelBuffer!, withPresentationTime: timeStamp)
                    }
            }
        }
        else {
            if (self.isRecording && self.audioWriter.isReadyForMoreMediaData) {
                DispatchQueue.main.async
                    {
                        self.audioWriter.append(sampleBuffer)
                }
            }
        }
    }
    
    // MARK: KVO and Notifications
    
    private var sessionRunningObserveContext = 0
    
    private func addObservers() {
        session.addObserver(self, forKeyPath: "running", options: .new, context: &sessionRunningObserveContext)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        session.removeObserver(self, forKeyPath: "running", context: &sessionRunningObserveContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &sessionRunningObserveContext {
            let newValue = change?[.newKey] as AnyObject?
            guard let isSessionRunning = newValue?.boolValue else { return }
            
            DispatchQueue.main.async { [unowned self] in
                // Only enable the ability to change camera if the device has more than one camera.
                self.cameraButton.isEnabled = isSessionRunning && self.videoDeviceDiscoverySession.uniqueDevicePositionsCount() > 1
                self.recordButton.isEnabled = isSessionRunning
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

extension AVCaptureDevice.DiscoverySession {
    func uniqueDevicePositionsCount() -> Int {
        var uniqueDevicePositions = [AVCaptureDevice.Position]()
        
        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }
        
        return uniqueDevicePositions.count
    }
}


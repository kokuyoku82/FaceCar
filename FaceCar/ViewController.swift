//
//  ViewController.swift
//  FaceCar
//
//  Created by Hao Lee on 2017/4/6.
//  Copyright © 2017年 Speed3D Inc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet var cameraView: UIView!
    
    //Session
    lazy var captureSession : AVCaptureSession = {
        let captureSession = AVCaptureSession()
        
        if captureSession.canAddOutput(self.capturePhotoOutput) {
            captureSession.addOutput(self.capturePhotoOutput)
        }
        if captureSession.canAddOutput(self.captureVideoDataOutput) {
            self.captureVideoDataOutput.setSampleBufferDelegate(self, queue: self.captureVideoDataOutputQueue)
            captureSession.addOutput(self.captureVideoDataOutput)
        }
        
        self.captureVideoPreviewLayer.session = captureSession
        self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        self.captureVideoPreviewLayer.frame = self.cameraView.bounds
        self.cameraView.layer.insertSublayer(self.captureVideoPreviewLayer, at: 0)
        
        return captureSession
    }()
    
    //Output
    private let capturePhotoOutput : AVCapturePhotoOutput = {
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        return capturePhotoOutput
    }()
    
    private let captureVideoDataOutput = AVCaptureVideoDataOutput()
    private var captureVideoDataOutputQueue = DispatchQueue(label: "captureVideoDataOutputQueue")
    
    //PreviewLayer
    let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    lazy var availableCameraInput : [AVCaptureDevicePosition : AVCaptureDeviceInput] = {
        
        var availableCameraInput = [AVCaptureDevicePosition : AVCaptureDeviceInput]()
        
        
        if let frontCamera = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera], mediaType: nil, position: AVCaptureDevicePosition.front).devices.first {
            if frontCamera.hasMediaType(AVMediaTypeVideo) {
                do {
                    let cameraInput = try AVCaptureDeviceInput(device: frontCamera)
                    availableCameraInput[.front] = cameraInput
                }
                catch {}
            }
        }
        
        if let backCamera = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera], mediaType: nil, position: AVCaptureDevicePosition.back).devices.first {
            if backCamera.hasMediaType(AVMediaTypeVideo) {
                do {
                    let cameraInput = try AVCaptureDeviceInput(device: backCamera)
                    availableCameraInput[.back] = cameraInput
                }
                catch {}
            }
        }
        
        return availableCameraInput
    }()
    
    var devicePosition : AVCaptureDevicePosition = .unspecified {
        didSet {
            
            self.captureSession.stopRunning()
            
            for input in self.captureSession.inputs {
                if let cameraInput = input as? AVCaptureDeviceInput {
                    self.captureSession.removeInput(cameraInput)
                }
            }
            
            if self.devicePosition != .unspecified {
                
                var deviceInput : AVCaptureDeviceInput? = nil
                
                if let input = self.availableCameraInput[self.devicePosition] {
                    deviceInput = input
                }
                else {
                    self.showAlertCameraUnavailable()
                }
                
                if let deviceInput = deviceInput {
                    self.captureSession.addInput(deviceInput)
                    self.captureSession.startRunning()
                }
            }
        }
    }
    
    //MARK: - Life Cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == .authorized {
            self.startPreview()
        }
        else {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted) -> Void in
                DispatchQueue.main.async {
                    if granted {
                        self.startPreview()
                    }
                    else {
                        var alertText = String()
                        alertText = alertText + NSLocalizedString("It looks like your privacy settings are preventing us from accessing your camera to do taking face photo. You can fix this by doing the following:", comment: "隱私權設定")
                        alertText = alertText + "\n\n1. "
                        alertText = alertText + NSLocalizedString("Touch the Go button below to open the Settings app.", comment: "隱私權設定")
                        alertText = alertText + "\n\n2. "
                        alertText = alertText + NSLocalizedString("Turn the Camera on.", comment: "隱私權設定")
                        alertText = alertText + "\n\n3. "
                        alertText = alertText + NSLocalizedString("Open this app and try again.", comment: "隱私權設定")
                        self.displayPrivacySettingsInstruction(alertText: alertText)
                    }
                }
            })
        }
    }
    
    func startPreview() {
        if self.availableCameraInput.count <= 1 {
            self.navigationItem.rightBarButtonItem = nil
        }
        
        if let _ = self.availableCameraInput[.front] {
            self.devicePosition = .front
        }
        else {
            if let _ = self.availableCameraInput[.back] {
                self.devicePosition = .back
            }
            else {
                self.showAlertCameraUnavailable()
            }
        }
    }
    
    func showAlertCameraUnavailable() {
        let alertView = UIAlertController(title: NSLocalizedString("Error", comment: "無相機可用"),
                                          message: NSLocalizedString("Camera is unavailable", comment: "無相機可用"),
                                          preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                          style: .default,
                                          handler: nil))
        self.present(alertView, animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.devicePosition = .unspecified //使相機關閉
        super.viewDidDisappear(animated)
    }
    
    //MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    private var faceDetector = CIDetector(ofType: CIDetectorTypeFace,
                                          context: nil,
                                          options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)! as CFDictionary
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!, options: attachments as? [String : AnyObject])
        let curDeviceOrientation = UIDevice.current.orientation
        var imageOptions = [String : Any]()
        
        imageOptions[CIDetectorEyeBlink] = true
        imageOptions[CIDetectorSmile] = true
        if self.devicePosition == .front {
            imageOptions[CIDetectorImageOrientation] = 5
        }
        else {
            imageOptions[CIDetectorImageOrientation] = 6
        }
        
        let features = self.faceDetector?.features(in: ciImage, options: imageOptions)
        if let face = features?.first as? CIFaceFeature {
            
            let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer)
            let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc!, false)
            
            DispatchQueue.main.async {
                self.drawFaces(face, forVideoBox: cleanAperture, orientation: curDeviceOrientation)
            }
        }
        else {
            DispatchQueue.main.async {
                self.legal = false
            }
        }
    }
    
    let featureLayer = CALayer()
    let featureLayerColors : [CGColor] = [UIColor.green.cgColor, UIColor.lightGray.cgColor]
    
    var legal = false {
        didSet {
            let index = self.legal ? 0 : 1
            self.featureLayer.borderColor = self.featureLayerColors[index]
        }
    }
    
    func drawFaces(_ face: CIFaceFeature,
                   forVideoBox clearAperture: CGRect,
                   orientation: UIDeviceOrientation){
        
        let parentFrameSize = self.captureVideoPreviewLayer.frame.size
        let gravity = self.captureVideoPreviewLayer.videoGravity
        let previewBox = self.videoPreviewBox(forGravity: gravity!,
                                              frameSize: parentFrameSize,
                                              apertureSize: clearAperture.size)
        
        if self.featureLayer.superlayer == nil {
            self.featureLayer.borderWidth = 3
            self.featureLayer.cornerRadius = 30
            self.captureVideoPreviewLayer.addSublayer(self.featureLayer)
        }
        self.featureLayer.isHidden = false
        
        let scaleBy = previewBox.width / clearAperture.height
        var m = CGAffineTransform.identity
        m = m.rotated(by: CGFloat.pi / 2)
        m = m.scaledBy(x: scaleBy, y: scaleBy)
        m = m.translatedBy(x: previewBox.origin.y/scaleBy, y: -clearAperture.height)
        
        let faceRect = face.bounds.applying(m)
        
        NSLog("Left: \(face.leftEyeClosed), Right: \(face.rightEyeClosed)")
        //        NSLog("Angle: \(face.faceAngle)")
        
        if abs(face.faceAngle) < 3 && !face.hasSmile {
            self.legal = true
        }
        else {
            self.legal = false
        }
        
        self.featureLayer.frame = faceRect
    }
    
    func videoPreviewBox(forGravity gravity: String,
                         frameSize: CGSize,
                         apertureSize:CGSize) -> CGRect {
        
        let apertureRatio = apertureSize.height / apertureSize.width
        let viewRatio = frameSize.width / frameSize.height
        
        var size = CGSize()
        switch gravity {
        case AVLayerVideoGravityResizeAspectFill:
            if viewRatio > apertureRatio {
                size.width = frameSize.width
                size.height = apertureSize.width * (frameSize.width / apertureSize.height)
            }
            else {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height
            }
        case AVLayerVideoGravityResizeAspect:
            if viewRatio > apertureRatio {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height
            }
            else {
                size.width = frameSize.width
                size.height = apertureSize.width * (frameSize.width / apertureSize.height)
            }
        default:
            size.width = frameSize.width
            size.height = frameSize.height
        }
        
        var origin = CGPoint()
        if size.width < frameSize.width {
            origin.x = (frameSize.width - size.width) / 2
        }
        else {
            origin.x = (size.width - frameSize.width) / 2
        }
        
        if size.height < frameSize.height {
            origin.y = (frameSize.height - size.height) / 2
        }
        else {
            origin.y = (size.height - frameSize.height) / 2
        }
        
        return CGRect(origin: origin, size: size)
    }
}

extension UIViewController {
    //MARK: - Alert
    func displayPrivacySettingsInstruction(alertText : String) {
        // `UIApplicationOpenSettingsURLString` availables in iOS 8.0 and later.
        // This APP supports iOS 8.0 or later.
        // So, we do not need to consider other cases in general.
        guard let openSettingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            return
        }
        
        let alertView = UIAlertController(title: NSLocalizedString("Warning", comment: "隱私權設定"),
                                          message: alertText,
                                          preferredStyle: .alert)
        
        alertView.addAction(UIAlertAction(title: NSLocalizedString("Close", comment: "隱私權設定"),
                                          style: .cancel))
        
        alertView.addAction(UIAlertAction(title: NSLocalizedString("Go", comment: "隱私權設定"),
                                          style: .default,
                                          handler: { (action :UIAlertAction) -> Void in
                                            UIApplication.shared.open(openSettingsURL)
        }))
        
        self.present(alertView, animated: true, completion: nil)
    }
}


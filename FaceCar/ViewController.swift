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
    @IBOutlet var carView: UIImageView!
    
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
    
    func turnCar(angle: CGFloat) {
        for constraint in self.view.constraints {
            if constraint.identifier == "carCenterX" {
                var multiplier = constraint.multiplier + angle
                
                multiplier = max(0.1, multiplier)
                multiplier = min(multiplier, 1)
                
                let newConstraint = NSLayoutConstraint(item: constraint.firstItem, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: multiplier, constant: constraint.constant)
                newConstraint.identifier = constraint.identifier
                self.view.removeConstraint(constraint)
                self.view.addConstraint(newConstraint)
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func gunOnCar() {
        for constraint in self.view.constraints {
            if constraint.identifier == "carVerticalSpace" {
                var multiplier = constraint.multiplier - 0.025
                multiplier = max(0.15, multiplier)
                
                let newConstraint = NSLayoutConstraint(item: constraint.firstItem, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: multiplier, constant: constraint.constant)
                newConstraint.identifier = constraint.identifier
                self.view.removeConstraint(constraint)
                self.view.addConstraint(newConstraint)
                self.view.layoutIfNeeded()
            }
        }
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
            DispatchQueue.main.async {
                self.controlCar(face)
            }
        }
    }
    
    // 臉部判斷的核心
    func controlCar(_ face: CIFaceFeature) {
        
        var angle = CGFloat(face.faceAngle)
        
        angle += face.leftEyeClosed ? -15 : 0
        angle += face.rightEyeClosed ? 15 : 0
        
        angle /= 200
        
        self.turnCar(angle: angle)
        
        if face.hasSmile {
            self.gunOnCar()
        }
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


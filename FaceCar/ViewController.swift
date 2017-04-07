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
import PBJVision

class ViewController: UIViewController {
    
    @IBOutlet var cameraView: UIView!
    @IBOutlet var carView: UIImageView!
    
    let finishMultiplier: CGFloat = 0.15
    
    //MARK: - Life Cycle
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        PBJVision.sharedInstance().previewLayer.frame = self.cameraView.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previewLayer = PBJVision.sharedInstance().previewLayer
        previewLayer.frame = self.cameraView.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.cameraView.layer.addSublayer(previewLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.resetCar()
        
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        PBJVision.sharedInstance().stopPreview()
    }
    
    func startPreview() {
        let vision = PBJVision.sharedInstance()
        vision.delegate = self
        vision.cameraMode = PBJCameraMode.video
        vision.cameraOrientation = .portrait
        vision.focusMode = .continuousAutoFocus
        vision.outputFormat = .square
        vision.cameraDevice = .front
        vision.additionalCompressionProperties = [AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline30]
        
        vision.startPreview()
    }
    
    func resetCar() {
        for constraint in self.view.constraints {
            if constraint.identifier == "carCenterX" {
                let multiplier = CGFloat(0.55)
                
                let newConstraint = NSLayoutConstraint(item: constraint.firstItem, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: multiplier, constant: constraint.constant)
                newConstraint.identifier = constraint.identifier
                self.view.removeConstraint(constraint)
                self.view.addConstraint(newConstraint)
                self.view.setNeedsLayout()
            }
        }
        
        for constraint in self.view.constraints {
            if constraint.identifier == "carVerticalSpace" {
                let multiplier = CGFloat(1)
                
                let newConstraint = NSLayoutConstraint(item: constraint.firstItem, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: multiplier, constant: constraint.constant)
                newConstraint.identifier = constraint.identifier
                self.view.removeConstraint(constraint)
                self.view.addConstraint(newConstraint)
                self.view.setNeedsLayout()
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
//        self.devicePosition = .unspecified //使相機關閉
        super.viewDidDisappear(animated)
    }
    
    func turnCar(angle: CGFloat) {
        var newAngle = self.carView.rotationAngle + angle / 180 * .pi
        newAngle = max(.pi / -2, newAngle)
        newAngle = min(newAngle, .pi / 2)
        self.carView.transform = CGAffineTransform(rotationAngle: newAngle)
    }
    
    func gunOnCar() {
        for constraint in self.view.constraints {
            if constraint.identifier == "carVerticalSpace" {
                var multiplier = constraint.multiplier - 0.005
                multiplier = max(0.15, multiplier)
                
                let newConstraint = NSLayoutConstraint(item: constraint.firstItem, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: multiplier, constant: constraint.constant)
                newConstraint.identifier = constraint.identifier
                self.view.removeConstraint(constraint)
                self.view.addConstraint(newConstraint)
                self.view.setNeedsLayout()
            }
        }
    }
    
    var faceDetector = CIDetector(ofType: CIDetectorTypeFace,
                                          context: nil,
                                          options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    // 臉部判斷的核心
    func controlCar(_ face: CIFaceFeature) {
        
        var angle = CGFloat(face.faceAngle)
        angle = 0
        
        angle += face.leftEyeClosed ? -10 : 0
        angle += face.rightEyeClosed ? 10 : 0
        
        self.turnCar(angle: angle)
        
        if face.hasSmile {
            self.gunOnCar()
        }
    }
}

extension ViewController: PBJVisionDelegate {
    func visionSessionDidStart(_ vision: PBJVision) {
        vision.startVideoCapture()
    }
    
    func vision(_ vision: PBJVision, didCaptureVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)! as CFDictionary
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!, options: attachments as? [String : AnyObject])
        var imageOptions = [String : Any]()

        imageOptions[CIDetectorEyeBlink] = true
        imageOptions[CIDetectorSmile] = true

        let features = self.faceDetector?.features(in: ciImage, options: imageOptions)
        if let face = features?.first as? CIFaceFeature {
            self.controlCar(face)
        }
        
        for constraint in self.view.constraints {
            if constraint.identifier == "carVerticalSpace" {
                if constraint.multiplier - 0.001 < self.finishMultiplier {
                    if vision.isRecording {
                        vision.endVideoCapture()
                    }
                }
            }
        }
    }
    
    func vision(_ vision: PBJVision, capturedVideo videoDict: [AnyHashable : Any]?, error: Error?) {
        let viewController = self.storyboard?.instantiateViewController(withIdentifier: "FinishViewController") as! FinishViewController
        if let videoPath = videoDict?[PBJVisionVideoPathKey] as? String {
            viewController.videoPath = videoPath
        }
        
        self.present(viewController, animated: true, completion: nil)
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

extension UIView {
    var rotationAngle: CGFloat {
        get {
            return self.value(forKeyPath: "layer.transform.rotation.z") as! CGFloat
        }
    }
}

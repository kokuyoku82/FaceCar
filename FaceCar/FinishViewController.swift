//
//  FinishViewController.swift
//  FaceCar
//
//  Created by Hao Lee on 2017/4/7.
//  Copyright © 2017年 Speed3D Inc. All rights reserved.
//

import UIKit
import PBJVideoPlayer

class FinishViewController: UIViewController {

    var videoPlayerController: PBJVideoPlayerController {
        get {
            return self.childViewControllers.reduce(nil, { (result, viewController) -> PBJVideoPlayerController? in
                return viewController is PBJVideoPlayerController ? viewController as? PBJVideoPlayerController : result
            })!
        }
    }
    var videoPath = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup media
        self.videoPlayerController.videoPath = self.videoPath;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func startNewGameAction(sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }

}

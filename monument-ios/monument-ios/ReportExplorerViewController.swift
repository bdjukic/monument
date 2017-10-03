//  Created by Bogdan Djukic on 2017-09-26.
//  Copyright © 2017 Bogdan Djukic. All rights reserved.
//

import UIKit
import Foundation
import WebKit
import AVKit
import AVFoundation

class ReportExplorerViewController : WebViewViewController,
                                     IPFSandEthereumConnectionStateDelegate,
                                     UIPageViewControllerDataSource,
                                     UIPageViewControllerDelegate {
    
    var pageViewController: UIPageViewController?
    var currentActivePlayController: AVPlayerViewController?
    
    // TODO: Not a great solution, but will work for now
    var orderedViewControllers: [UIViewController]?
    var orderedReportDescriptions: [String]?
    
    @IBOutlet weak var descriptionTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        super.delegate = self
        
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageViewController?.dataSource = self
        pageViewController?.delegate = self
        
        view.addSubview((pageViewController?.view)!)
        
        descriptionTextView.layer.cornerRadius = 10
        view.bringSubview(toFront: descriptionTextView)
        
        orderedViewControllers = []
        orderedReportDescriptions = []
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if (currentActivePlayController != nil) {
            currentActivePlayController?.player?.seek(to: kCMTimeZero)
            currentActivePlayController?.player?.play()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (currentActivePlayController != nil) {
            currentActivePlayController?.player?.seek(to: kCMTimeZero)
            currentActivePlayController?.player?.rate = 0
        }
    }
    
    func loadReports() {
        orderedViewControllers?.removeAll()
        orderedReportDescriptions?.removeAll()
        
        self.webView?.evaluateJavaScript("listReports()", completionHandler: { (result, error) in
            if error == nil {
                let reports = result as! Array<Array<Any>>
                for report in reports {
                    let hash = report[0] as! String
                    let reportDescription = report[2] as! String
                    
                    let playerController = AVPlayerViewController.init()
                    playerController.showsPlaybackControls = false
                    playerController.player = AVPlayer.init(url: URL.init(string: "http://192.168.0.20:8080/ipfs/" + hash)!)
                    
                    self.orderedViewControllers?.append(playerController)
                    self.orderedReportDescriptions?.append(reportDescription)
                }
                
                if let firstViewController = self.orderedViewControllers?.first {
                    self.pageViewController?.setViewControllers([firstViewController],
                                                                direction: .forward,
                                                                animated: true,
                                                                completion: nil)
                    
                    self.currentActivePlayController = firstViewController as? AVPlayerViewController
                    self.currentActivePlayController?.player?.play()
                }
                
                if let firstReportDescription = self.orderedReportDescriptions?.first {
                    self.descriptionTextView.isHidden = false
                    self.descriptionTextView.text = firstReportDescription
                }
            }
            else {
                print("Error occured while executing smart contract.")
            }
        })
    }
    
    func clientConnected() {
        loadReports()
    }
    
    @IBAction func reloadReports(_ sender: Any) {
        loadReports()
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let viewControllerIndex = orderedViewControllers?.index(of: pendingViewControllers[0]) else {
            return
        }
        
        let currentReportDescription = orderedReportDescriptions![viewControllerIndex]
        descriptionTextView.text = currentReportDescription
        
        currentActivePlayController = (orderedViewControllers![viewControllerIndex] as! AVPlayerViewController)
        currentActivePlayController?.player?.play()
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let viewControllerIndex = orderedViewControllers?.index(of: previousViewControllers[0]) else {
            return
        }
        
        let playerController = (orderedViewControllers![viewControllerIndex] as! AVPlayerViewController)
        playerController.player?.seek(to: kCMTimeZero)
        playerController.player?.rate = 0
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers?.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return orderedViewControllers?.last
        }
        
        guard (orderedViewControllers?.count)! > previousIndex else {
            return nil
        }
        
        return orderedViewControllers?[previousIndex]
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers?.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        
        guard (orderedViewControllers?.count)! != nextIndex else {
            return orderedViewControllers?.first
        }
        
        guard (orderedViewControllers?.count)! > nextIndex else {
            return nil
        }
        
        return orderedViewControllers?[nextIndex]
    }
}

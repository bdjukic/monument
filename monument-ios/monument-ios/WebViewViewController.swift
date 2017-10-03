//  Created by Bogdan Djukic on 2017-09-26.
//  Copyright © 2017 Bogdan Djukic. All rights reserved.
//

import UIKit
import Foundation
import WebKit
import SwiftIpfsApi
import SwiftMultihash

protocol IPFSandEthereumConnectionStateDelegate {
    func clientConnected()
}

class WebViewViewController : UIViewController, WKNavigationDelegate {
    var webView: WKWebView?
    
    var ipfsApi: IpfsApi?
    var ipfsHash: String?
    
    var ipfsConnected: Bool = false
    var ethereumConnected: Bool = false
    
    var delegate: IPFSandEthereumConnectionStateDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            ipfsApi = try IpfsApi(host: "192.168.0.20", port: 5001)
            
            try ipfsApi?.id() {
                (idData : JsonType) in
                print("Connected to IPFS node: " + (idData.object?["ID"]?.string)!)
                
                self.ipfsConnected = true
                self.checkConnectivity()
            }
        }
        catch {
            print("Failed to connect to IPFS node.")
        }
        
        webView = WKWebView()
        view.addSubview(webView!)
        
        webView!.navigationDelegate = self
        
        if let url = Bundle.main.url(forResource: "web3", withExtension: "html")
        {
            do
            {
                if let web3url = Bundle.main.url(forResource: "web3", withExtension: "js") {
                    let htmlContents = try String(contentsOfFile: url.path)
                    webView?.loadHTMLString(htmlContents, baseURL: web3url.deletingLastPathComponent())
                }
            }
            catch
            {
                print("Could not load the HTML page.")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView loaded.")
        
        webView.evaluateJavaScript("isConnectedToEthereumNode()", completionHandler: { (result, error) in
            if error == nil && result != nil {
                let nodeConnected = result! as! Bool
                
                if (nodeConnected) {
                    print("Ethereum node connected.")
                    
                    self.ethereumConnected = true
                    self.checkConnectivity()
                }
                else {
                    print("Failed to connect to Ethereum.")
                }
            }
        })
    }
    
    func checkConnectivity() {
        if (ipfsConnected && ethereumConnected) {
            DispatchQueue.main.async
                {
                    self.delegate?.clientConnected()
                }
        }
    }
}


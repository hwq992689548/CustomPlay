//
//  AppDelegate.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/23.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        self.window = UIWindow.init(frame: UIScreen.main.bounds)
        let navi = UINavigationController.init(rootViewController: ViewController())
        self.window?.rootViewController = navi
        self.window?.makeKeyAndVisible()
        
        return true
    }

   
}


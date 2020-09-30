//
//  AppDelegate.swift
//  Sample
//
//  Created by Théophane Rupin on 6/12/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import UIKit
import Lucid

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let dependencies = MainDependencyContainer.appDelegateDependencyResolver()
    
    @Weaver(.registration)
    private var movieDBClient: MovieDBClient

    @Weaver(.registration, builder: CoreManagerContainer.make)
    private var managers: MovieCoreManagerProviding
    
    @Weaver(.registration, scope: .transient)
    private var movieList: MovieList

    @Weaver(.registration)
    private var imageManager: ImageManager

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

// MARK: - Builders

extension CoreManagerContainer {

    static func make(_ dependencies: MovieDBClientResolver) -> CoreManagerContainer {
        return CoreManagerContainer(cacheLimit: 500, client: dependencies.movieDBClient)
    }
}

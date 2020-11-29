//
//  LucidWeaverApp.swift
//  LucidWeaver
//
//  Created by Théophane Rupin on 11/27/20.
//

import SwiftUI

@main
struct LucidWeaverApp: App {

    let dependencies: AppDelegateDependencyResolver = {
        UITableView.appearance().allowsSelection = false
        UITableViewCell.appearance().selectionStyle = .none
        return MainDependencyContainer.appDelegateDependencyResolver()
    }()

    @Weaver(.registration)
    private var movieDBClient: MovieDBClient

    @Weaver(.registration, builder: CoreManagerContainer.make)
    private var managers: MovieCoreManagerProviding

    @Weaver(.registration, scope: .transient)
    private var movieList: MovieList

    @Weaver(.registration)
    private var imageManager: ImageManager

    var body: some Scene {
        WindowGroup {
            movieList
        }
    }
}

// MARK: - Builders
extension CoreManagerContainer {

    static func make(_ dependencies: MovieDBClientResolver) -> CoreManagerContainer {
        return CoreManagerContainer(cacheLimit: 500, client: dependencies.movieDBClient)
    }
}

//
//  ContentView.swift
//  Sample
//
//  Created by Théophane Rupin on 6/12/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import SwiftUI
import Lucid
import Combine

final class MovieRowViewModel: ObservableObject {

    fileprivate let movie: Movie

    fileprivate var cancellables = Set<AnyCancellable>()

    @Published
    fileprivate var image: UIImage?

    init(_ movie: Movie) {
        self.movie = movie
    }

    fileprivate func cancel() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    fileprivate var isLoading: Bool {
        return cancellables.isEmpty == false
    }
}

struct MovieRow: View {

    @ObservedObject
    var viewModel: MovieRowViewModel

    private let controller: MovieListController

    init(viewModel: MovieRowViewModel, controller: MovieListController) {
        self.viewModel = viewModel
        self.controller = controller
    }

    var body: some View {
        HStack {
            image
        }.onAppear {
            self.controller.load(in: self.viewModel)
        }
        .onDisappear {
            self.viewModel.cancel()
        }
    }

    private var image: some View {
        Group {
            if viewModel.image != nil {
                Image(uiImage: viewModel.image!).resizable()
            } else {
                Text("Loading...")
            }
        }
            .frame(minHeight: 600, maxHeight: 600)
            .aspectRatio(2 / 3, contentMode: .fit)
    }
}

final class MovieListController {

    @Weaver(.registration)
    private var movieManager: MovieManager

    @Weaver(.reference)
    private var imageManager: ImageManager

    init(injecting _: MovieListControllerDependencyResolver) {
        // no-op
    }

    fileprivate func load(in viewModel: MovieListViewModel) {
        loadNextPage(in: viewModel, for: -1)
    }

    fileprivate func loadNextPage(in viewModel: MovieListViewModel, for offset: Int) {
        guard offset == viewModel.movies.count - 1 else { return }

        viewModel.cancel()
        movieManager
            .discoverMovies(at: offset + 1)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished: break
                case .failure(let error):
                    Logger.log(.error, "\(MovieListController.self): Could not load next page: \(error)")
                }
            }, receiveValue: { result in
                viewModel.movies.append(contentsOf: result.movies)
            })
            .store(in: &viewModel.cancellables)
    }

    fileprivate func load(in rowViewModel: MovieRowViewModel) {
        guard rowViewModel.isLoading == false else {
            return
        }
        imageManager
            .image(for: rowViewModel.movie.posterPath.absoluteString)
            .receive(on: DispatchQueue.main)
            .map { .some($0) }
            .replaceError(with: .none)
            .assign(to: \.image, on: rowViewModel)
            .store(in: &rowViewModel.cancellables)
    }
}

final class MovieListViewModel: Combine.ObservableObject {

    fileprivate var cancellables = Set<AnyCancellable>()

    @Combine.Published
    fileprivate var movies: [Movie] = []

    fileprivate func cancel() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

struct MovieList: View {

    @ObservedObject
    private var viewModel = MovieListViewModel()

    @Weaver(.registration)
    private var controller: MovieListController

    @WeaverP1(.registration, scope: .transient)
    private var movieDetail: (MovieDetailViewModel) -> MovieDetail

    init(injecting _: MovieListDependencyResolver) {
        // no-op
    }

    var body: some View {
        NavigationView {
            List(0..<viewModel.movies.count, id: \.self) { index in
                NavigationLink(destination: self.movieDetail(at: index)) {
                    MovieRow(
                        viewModel: MovieRowViewModel(self.viewModel.movies[index]),
                        controller: self.controller
                    ).onAppear {
                        self.controller.loadNextPage(in: self.viewModel, for: index)
                    }
                }
            }.onAppear {
                self.controller.load(in: self.viewModel)
            }.navigationBarTitle("Most Popular Movies")
        }
    }

    private func movieDetail(at index: Int) -> some View {
        return movieDetail(MovieDetailViewModel(viewModel.movies[index]))
    }
}

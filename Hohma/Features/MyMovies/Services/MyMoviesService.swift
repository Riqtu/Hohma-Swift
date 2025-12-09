import Foundation

@MainActor
final class MyMoviesService: ObservableObject, TRPCServiceProtocol {
    static let shared = MyMoviesService()
    private init() {}

    func search(query: String, page: Int = 1, limit: Int = 10) async throws -> SearchMoviesResponse {
        let input: [String: Any] = ["query": query, "page": page, "limit": limit]
        return try await trpcService.executeGET(endpoint: "movies.search", input: input)
    }

    func addToMy(kpId: String, isWatched: Bool = false, userRating: Int? = nil)
        async throws -> (movie: MovieRecord, userMovie: UserMovieRecord)
    {
        var body: [String: Any] = ["kpId": kpId, "isWatched": isWatched]
        if let userRating { body["userRating"] = userRating }
        struct Response: Decodable {
            let movie: MovieRecord
            let userMovie: UserMovieRecord
        }
        let result: Response = try await trpcService.executePOST(
            endpoint: "movies.addToMy",
            body: body
        )
        return (result.movie, result.userMovie)
    }

    func updateMy(movieId: String, isWatched: Bool?, userRating: Int?)
        async throws -> (movie: MovieRecord, userMovie: UserMovieRecord)
    {
        var body: [String: Any] = ["movieId": movieId]
        if let isWatched { body["isWatched"] = isWatched }
        if let userRating { body["userRating"] = userRating }
        struct Response: Decodable {
            let movie: MovieRecord
            let userMovie: UserMovieRecord
        }
        let result: Response = try await trpcService.executePOST(
            endpoint: "movies.updateMy",
            body: body
        )
        return (result.movie, result.userMovie)
    }

    func removeFromMy(movieId: String) async throws {
        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "movies.removeFromMy",
            body: ["movieId": movieId]
        )
    }

    func myMovies(page: Int = 1, limit: Int = 20, watched: Bool? = nil, sort: String? = nil)
        async throws -> MyMoviesResponse
    {
        var input: [String: Any] = ["page": page, "limit": limit]
        if let watched { input["watched"] = watched }
        if let sort { input["sort"] = sort }
        return try await trpcService.executeGET(endpoint: "movies.my", input: input)
    }

    func getMovie(id: String) async throws -> MovieRecord {
        return try await trpcService.executeGET(
            endpoint: "movies.getById",
            input: ["id": id]
        )
    }
}


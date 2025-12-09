import Foundation

struct MovieName: Codable {
    let name: String
    let language: String?
    let nameType: String?
}

struct MovieGenre: Codable {
    let name: String
}

struct MovieCountry: Codable {
    let name: String
}

struct MovieReleaseYear: Codable {
    let start: Int?
    let end: Int?
}

struct UserMovieRecord: Codable {
    let id: String
    let isWatched: Bool
    let userRating: Int?
    let createdAt: String
    let updatedAt: String
}

struct MovieRecord: Codable, Identifiable {
    let id: String
    let kpId: String
    let imdbId: String?
    let tmdbId: String?
    let kpHdId: String?
    let type: String?
    let name: String?
    let alternativeName: String?
    let enName: String?
    let year: Int?
    let description: String?
    let shortDescription: String?
    let movieLength: Int?
    let isSeries: Bool?
    let ticketsOnSale: Bool?
    let totalSeriesLength: Int?
    let seriesLength: Int?
    let ratingMpaa: String?
    let ageRating: Int?
    let top10: Int?
    let top250: Int?
    let typeNumber: Int?
    let status: String?
    let posterUrl: String?
    let posterPreviewUrl: String?
    let backdropUrl: String?
    let backdropPreviewUrl: String?
    let logoUrl: String?
    let logoPreviewUrl: String?
    let ratingKp: Double?
    let ratingImdb: Double?
    let ratingFilmCritics: Double?
    let ratingRussianFilmCritics: Double?
    let ratingAwait: Double?
    let votesKp: Int?
    let votesImdb: Int?
    let votesFilmCritics: Int?
    let votesRussianFilmCritics: Int?
    let votesAwait: Int?
    let names: [MovieName]?
    let genres: [MovieGenre]?
    let countries: [MovieCountry]?
    let releaseYears: [MovieReleaseYear]?
    var userMovies: [UserMovieRecord]?
}

struct MyMovieListItem: Codable, Identifiable {
    let id: String
    let movieId: String
    let userId: String
    let isWatched: Bool
    let userRating: Int?
    let createdAt: String
    let updatedAt: String
    let movie: MovieRecord
}

struct MyMoviesResponse: Codable {
    let items: [MyMovieListItem]
    let total: Int
    let page: Int
    let pages: Int
}

struct SearchMoviesResponse: Codable {
    let docs: [MovieSearchDoc]
}

struct MovieSearchDoc: Codable, Identifiable {
    let id: Int
    let name: String?
    let alternativeName: String?
    let year: Int?
    let poster: Poster?
    let description: String?

    struct Poster: Codable {
        let url: String?
        let previewUrl: String?
    }
}


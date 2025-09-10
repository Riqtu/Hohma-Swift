import Foundation
import SwiftUI

@MainActor
class RaceListViewModel: ObservableObject, TRPCServiceProtocol {
    @Published var races: [Race] = []
    @Published var roads: [Road] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateRace = false
    @Published var selectedRace: Race?
    @Published var showingRaceDetail = false

    // Filters
    @Published var selectedStatus: RaceStatus?
    @Published var selectedRoad: Road?
    @Published var showPrivateRaces = false

    init() {
        loadRaces()
        loadRoads()
    }

    // MARK: - Load Data
    func loadRaces() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response: [Race] = try await trpcService.executeGET(
                    endpoint: "race.getRaces",
                    input: buildRaceFilters()
                )

                races = response
                isLoading = false
            } catch {
                errorMessage = "Ошибка загрузки скачек: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func loadRoads() {
        Task {
            do {
                let response: [Road] = try await trpcService.executeGET(
                    endpoint: "race.getRoads",
                    input: ["limit": 50, "offset": 0]
                )

                roads = response
            } catch {
                print("Ошибка загрузки дорог: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create Race
    func createRace(name: String, roadId: String, maxPlayers: Int, entryFee: Int, isPrivate: Bool) {
        isLoading = true
        errorMessage = nil

        let request: [String: Any] = [
            "name": name,
            "roadId": roadId,
            "maxPlayers": maxPlayers,
            "entryFee": entryFee,
            "isPrivate": isPrivate,
            "theme": "default",
        ]

        Task {
            do {
                let _: Race = try await trpcService.executePOST(
                    endpoint: "race.createRace",
                    body: request
                )

                showingCreateRace = false
                loadRaces()  // Reload races
                isLoading = false
            } catch {
                errorMessage = "Ошибка создания скачки: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Join Race
    func joinRace(raceId: String) {
        isLoading = true
        errorMessage = nil

        let request: [String: Any] = ["raceId": raceId]

        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.joinRace",
                    body: request
                )

                loadRaces()  // Reload races
                isLoading = false
            } catch {
                errorMessage = "Ошибка присоединения к скачке: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Start Race
    func startRace(raceId: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.startRace",
                    body: ["raceId": raceId]
                )

                loadRaces()  // Reload races
                isLoading = false
            } catch {
                errorMessage = "Ошибка запуска скачки: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Delete Race
    func deleteRace(raceId: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.deleteRace",
                    body: ["raceId": raceId]
                )

                loadRaces()  // Reload races
                isLoading = false
            } catch {
                errorMessage = "Ошибка удаления скачки: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Navigation
    func showRaceDetail(_ race: Race) {
        selectedRace = race
        showingRaceDetail = true
    }

    // MARK: - Filters
    func applyFilters() {
        loadRaces()
    }

    func clearFilters() {
        selectedStatus = nil
        selectedRoad = nil
        showPrivateRaces = false
        loadRaces()
    }

    private func buildRaceFilters() -> [String: Any] {
        var filters: [String: Any] = [
            "limit": 50,
            "offset": 0,
        ]

        if let status = selectedStatus {
            filters["status"] = status.rawValue
        }

        if let road = selectedRoad {
            filters["roadId"] = road.id
        }

        if showPrivateRaces {
            filters["isPrivate"] = true
        }

        return filters
    }

    // MARK: - Computed Properties
    var filteredRaces: [Race] {
        var filtered = races

        if !showPrivateRaces {
            filtered = filtered.filter { !$0.isPrivate }
        }

        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }

        if let road = selectedRoad {
            filtered = filtered.filter { $0.road.id == road.id }
        }

        return filtered
    }

    var canCreateRace: Bool {
        return !roads.isEmpty
    }

    var activeRaces: [Race] {
        return races.filter { $0.status == .running }
    }

    var myRaces: [Race] {
        // This would need to be filtered by current user ID
        // For now, return all races
        return races
    }
}

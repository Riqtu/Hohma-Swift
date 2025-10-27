import Inject
import SwiftUI

struct CreateRaceView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: RaceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var raceName = ""
    @State private var selectedRoad: Road?
    @State private var maxPlayers = 4
    @State private var entryFee = 0
    @State private var isPrivate = false

    var body: some View {
        NavigationView {
            Form {
                Section("Основная информация") {
                    TextField("Название скачки", text: $raceName)

                    Picker("Дорога", selection: $selectedRoad) {
                        Text("Выберите дорогу").tag(nil as Road?)
                        ForEach(viewModel.roads) { road in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(road.name)
                                    Text(
                                        "\(road.length) клеток • \(road.difficulty.displayName)"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .tag(road as Road?)
                        }
                    }
                }

                Section("Настройки") {
                    Stepper("Максимум игроков: \(maxPlayers)", value: $maxPlayers, in: 2...8)

                    Stepper(
                        "Взнос: \(entryFee) монет", value: $entryFee, in: 0...1000, step: 10)

                    Toggle("Приватная скачка", isOn: $isPrivate)
                }

                if let road = selectedRoad {
                    Section("Информация о дороге") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Название:")
                                Spacer()
                                Text(road.name)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Длина:")
                                Spacer()
                                Text("\(road.length) клеток")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Сложность:")
                                Spacer()
                                Text(road.difficulty.displayName)
                                    .foregroundColor(.secondary)
                            }

                            if let description = road.description, !description.isEmpty {
                                HStack {
                                    Text("Описание:")
                                    Spacer()
                                    Text(description)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Призовой фонд: \(entryFee * maxPlayers) монет")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("Призовой фонд формируется из взносов всех участников")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Создать скачку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        createRace()
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
        }
        .enableInjection()
    }

    private var isFormValid: Bool {
        !raceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedRoad != nil
            && maxPlayers >= 2 && maxPlayers <= 8
    }

    private func createRace() {
        guard let road = selectedRoad else { return }

        viewModel.createRace(
            name: raceName.trimmingCharacters(in: .whitespacesAndNewlines),
            roadId: road.id,
            maxPlayers: maxPlayers,
            entryFee: entryFee,
            isPrivate: isPrivate
        )
    }
}

#Preview {
    CreateRaceView(viewModel: RaceListViewModel())
}

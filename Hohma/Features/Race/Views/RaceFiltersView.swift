import Inject
import SwiftUI

struct RaceFiltersView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: RaceListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Статус") {
                    Picker("Статус", selection: $viewModel.selectedStatus) {
                        Text("Все").tag(nil as RaceStatus?)
                        ForEach(RaceStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status as RaceStatus?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Дорога") {
                    Picker("Дорога", selection: $viewModel.selectedRoad) {
                        Text("Все дороги").tag(nil as Road?)
                        ForEach(viewModel.roads) { road in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(road.name)
                                    Text("\(road.length) клеток • \(road.difficulty.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .tag(road as Road?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Дополнительно") {
                    Toggle("Показывать приватные", isOn: $viewModel.showPrivateRaces)
                }

                Section {
                    Button("Сбросить фильтры") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Применить") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
            }
        }
        .enableInjection()
    }
}

#Preview {
    RaceFiltersView(viewModel: RaceListViewModel())
}

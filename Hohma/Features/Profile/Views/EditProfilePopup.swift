//
//  EditProfilePopup.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Inject
import SwiftUI

struct EditProfilePopup: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Заголовок
                    VStack(spacing: 8) {
                        Text("Редактировать профиль")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Обновите информацию о себе")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)

                    // Форма редактирования
                    VStack(spacing: 12) {
                        ProfileTextField(
                            title: "Имя пользователя",
                            placeholder: "Введите имя пользователя",
                            text: $viewModel.username,
                            icon: "person"
                        )

                        ProfileTextField(
                            title: "Имя",
                            placeholder: "Введите имя",
                            text: $viewModel.firstName,
                            icon: "person.text.rectangle"
                        )

                        ProfileTextField(
                            title: "Фамилия",
                            placeholder: "Введите фамилию",
                            text: $viewModel.lastName,
                            icon: "person.text.rectangle"
                        )

                        // Загрузка аватара
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)

                                Text("Аватар")
                                    .font(.headline)

                                Spacer()
                            }

                            ImageUploadButton { fileURL in
                                viewModel.avatarUrl = fileURL
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Сообщения об ошибках и успехе
                    VStack(spacing: 8) {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }

                        if let successMessage = viewModel.successMessage {
                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Кнопки
                    VStack(spacing: 12) {
                        PrimaryButton(
                            title: viewModel.isUpdating ? "Обновление..." : "Сохранить изменения"
                        ) {
                            viewModel.updateProfile()
                        }
                        .disabled(viewModel.isUpdating)

                        Button("Отмена") {
                            isPresented = false
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        isPresented = false
                    }
                }
            }
            .appBackground()
        }
        .enableInjection()
    }
}

#Preview {
    EditProfilePopup(
        viewModel: ProfileViewModel(authViewModel: AuthViewModel()),
        isPresented: .constant(true)
    )
}

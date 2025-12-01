//
//  CacheSettingsView.swift
//  Hohma
//
//  Created for cache management settings
//

import SwiftUI
import Inject

struct CacheSettingsView: View {
    @ObserveInjection var inject
    @StateObject private var cacheManager = CacheManagerService.shared
    @State private var showingClearAllAlert = false
    @State private var showingClearURLCacheAlert = false
    @State private var showingClearAvatarAlert = false
    @State private var memoryLimitMB: Double = 50
    @State private var diskLimitMB: Double = 200
    @State private var isClearing = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Информация о кэше
                cacheInfoSection
                
                // Настройки лимитов
                cacheLimitsSection
                
                // Управление кэшем
                cacheManagementSection
            }
            .navigationTitle("Управление кэшем")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateLimitsFromCache()
                cacheManager.updateCacheSizes()
            }
            .overlay {
                if isClearing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Очистка кэша...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
            .alert("Очистить весь кэш?", isPresented: $showingClearAllAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    clearAllCaches()
                }
            } message: {
                Text("Это действие удалит все кэшированные данные, включая изображения и медиа. Приложение может работать медленнее до повторной загрузки данных.")
            }
            .alert("Очистить URL кэш?", isPresented: $showingClearURLCacheAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    clearURLCache()
                }
            } message: {
                Text("Это действие удалит кэш сетевых запросов. Изображения и другие данные будут загружены заново при следующем использовании.")
            }
            .alert("Очистить кэш аватарок?", isPresented: $showingClearAvatarAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    clearAvatarCache()
                }
            } message: {
                Text("Это действие удалит кэш аватарок пользователей. Аватары будут загружены заново при следующем просмотре.")
            }
            .alert("Готово", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
        }
        .enableInjection()
    }
    
    // MARK: - Cache Info Section
    
    private var cacheInfoSection: some View {
        let diskLimitBytes = Int64(diskLimitMB * 1024 * 1024)
        let isOverLimit = cacheManager.diskCacheSize > diskLimitBytes
        
        return Section {
            HStack {
                Text("Размер кэша")
                Spacer()
                if cacheManager.diskCacheSize > 0 {
                    Text(cacheManager.formatBytes(cacheManager.diskCacheSize))
                        .foregroundColor(isOverLimit ? .red : .secondary)
                        .fontWeight(isOverLimit ? .semibold : .regular)
                } else {
                    Text("0 KB")
                        .foregroundColor(.secondary)
                }
            }
            
            if isOverLimit {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Размер кэша превышает лимит")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text("Лимит памяти")
                Spacer()
                Text("\(Int(memoryLimitMB)) MB")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Лимит диска")
                Spacer()
                Text("\(Int(diskLimitMB)) MB")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Информация о кэше")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Размер кэша показывает реальное занятое место в Caches, Documents и временных файлах.")
                Text("Лимиты определяют максимальный размер URLCache.")
                if isOverLimit {
                    Text("\n⚠️ При превышении лимита URLCache автоматически удаляет старые записи (LRU - Least Recently Used). Рекомендуется очистить кэш вручную.")
                        .foregroundColor(.orange)
                } else {
                    Text("\n💡 URLCache автоматически управляет размером: при превышении лимита старые записи удаляются автоматически.")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Cache Limits Section
    
    private var cacheLimitsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Лимит памяти")
                    Spacer()
                    Text("\(Int(memoryLimitMB)) MB")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $memoryLimitMB,
                    in: 50...300,
                    step: 10
                ) {
                    Text("Лимит памяти")
                } minimumValueLabel: {
                    Text("50 MB")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("300 MB")
                        .font(.caption)
                }
                .onChange(of: memoryLimitMB) { _, newValue in
                    let limitInBytes = Int(newValue) * 1024 * 1024
                    cacheManager.setMemoryLimit(limitInBytes)
                }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Лимит диска")
                    Spacer()
                    Text("\(Int(diskLimitMB)) MB")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $diskLimitMB,
                    in: 100...2000,
                    step: 50
                ) {
                    Text("Лимит диска")
                } minimumValueLabel: {
                    Text("100 MB")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("2000 MB")
                        .font(.caption)
                }
                .onChange(of: diskLimitMB) { _, newValue in
                    let limitInBytes = Int(newValue) * 1024 * 1024
                    cacheManager.setDiskLimit(limitInBytes)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Лимиты кэша")
        } footer: {
            Text("Увеличьте лимиты для лучшей производительности при работе с медиа (фото, видео, стикеры). Лимит памяти влияет на скорость загрузки, лимит диска - на количество кэшированных данных.")
        }
    }
    
    // MARK: - Cache Management Section
    
    private var cacheManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showingClearURLCacheAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Очистить URL кэш")
                }
            }
            
            Button(role: .destructive) {
                showingClearAvatarAlert = true
            } label: {
                HStack {
                    Image(systemName: "person.circle")
                    Text("Очистить кэш аватарок")
                }
            }
            
            Button(role: .destructive) {
                clearTemporaryFiles()
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Очистить временные файлы")
                }
            }
            
            Button(role: .destructive) {
                showingClearAllAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Очистить весь кэш")
                }
            }
        } header: {
            Text("Управление кэшем")
        } footer: {
            Text("Очистка кэша может временно замедлить работу приложения, пока данные не будут загружены заново.")
        }
    }
    
    // MARK: - Helpers
    
    private func updateLimitsFromCache() {
        memoryLimitMB = Double(cacheManager.getMemoryLimit()) / 1024.0 / 1024.0
        diskLimitMB = Double(cacheManager.getDiskLimit()) / 1024.0 / 1024.0
    }
    
    private func clearURLCache() {
        isClearing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cacheManager.clearURLCache()
            // Увеличиваем задержку для полной очистки и обновления размеров
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isClearing = false
                successMessage = "URL кэш успешно очищен"
                showSuccessMessage = true
                // Принудительно обновляем размеры
                cacheManager.updateCacheSizes()
            }
        }
    }
    
    private func clearAvatarCache() {
        isClearing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cacheManager.clearAvatarCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isClearing = false
                successMessage = "Кэш аватарок успешно очищен"
                showSuccessMessage = true
            }
        }
    }
    
    private func clearTemporaryFiles() {
        isClearing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                await cacheManager.clearTemporaryFiles()
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isClearing = false
                        successMessage = "Временные файлы успешно очищены"
                        showSuccessMessage = true
                        cacheManager.updateCacheSizes()
                    }
                }
            }
        }
    }
    
    private func clearAllCaches() {
        isClearing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cacheManager.clearAllCaches()
            // Увеличиваем задержку для полной очистки всех кэшей
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isClearing = false
                successMessage = "Весь кэш успешно очищен"
                showSuccessMessage = true
                // Принудительно обновляем размеры
                cacheManager.updateCacheSizes()
            }
        }
    }
}

#Preview {
    CacheSettingsView()
}


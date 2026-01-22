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
    @State private var showingClearImageCacheAlert = false
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
            .navigationTitle("cache.title".localized)
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
                            Text("cache.clearing".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
            .alert("cache.clearAllAlert.title".localized, isPresented: $showingClearAllAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("cache.clearAll".localized, role: .destructive) {
                    clearAllCaches()
                }
            } message: {
                Text("cache.clearAllAlert.message".localized)
            }
            .alert("cache.clearURLCacheAlert.title".localized, isPresented: $showingClearURLCacheAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("cache.clearURLCache".localized, role: .destructive) {
                    clearURLCache()
                }
            } message: {
                Text("cache.clearURLCacheAlert.message".localized)
            }
            .alert("cache.clearImageCacheAlert.title".localized, isPresented: $showingClearImageCacheAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("cache.clearImageCache".localized, role: .destructive) {
                    clearImageCache()
                }
            } message: {
                Text("cache.clearImageCacheAlert.message".localized)
            }
            .alert("cache.clearAvatarCacheAlert.title".localized, isPresented: $showingClearAvatarAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("cache.clearAvatarCache".localized, role: .destructive) {
                    clearAvatarCache()
                }
            } message: {
                Text("cache.clearAvatarCacheAlert.message".localized)
            }
            .alert("common.ok".localized, isPresented: $showSuccessMessage) {
                Button("common.ok".localized, role: .cancel) {}
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
                Text("cache.size".localized)
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
                    Text("cache.overLimit".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text("cache.memoryLimit".localized)
                Spacer()
                Text("\(Int(memoryLimitMB)) MB")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("cache.diskLimit".localized)
                Spacer()
                Text("\(Int(diskLimitMB)) MB")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("cache.info.title".localized)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("cache.info.sizeDescription".localized)
                Text("cache.info.limitsDescription".localized)
                if isOverLimit {
                    Text("\n\(NSLocalizedString("cache.info.overLimitWarning", comment: ""))")
                        .foregroundColor(.orange)
                } else {
                    Text("\n\(NSLocalizedString("cache.info.autoManagement", comment: ""))")
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
                    Text("cache.memoryLimit".localized)
                    Spacer()
                    Text("\(Int(memoryLimitMB)) MB")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $memoryLimitMB,
                    in: 50...300,
                    step: 10
                ) {
                    Text("cache.memoryLimit".localized)
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
                    Text("cache.diskLimit".localized)
                    Spacer()
                    Text("\(Int(diskLimitMB)) MB")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $diskLimitMB,
                    in: 100...2000,
                    step: 50
                ) {
                    Text("cache.diskLimit".localized)
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
            Text("cache.limits.title".localized)
        } footer: {
            Text("cache.limits.description".localized)
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
                    Text("cache.clearURLCache".localized)
                }
            }
            
            Button(role: .destructive) {
                showingClearImageCacheAlert = true
            } label: {
                HStack {
                    Image(systemName: "photo")
                    Text("cache.clearImageCache".localized)
                }
            }
            
            Button(role: .destructive) {
                showingClearAvatarAlert = true
            } label: {
                HStack {
                    Image(systemName: "person.circle")
                    Text("cache.clearAvatarCache".localized)
                }
            }
            
            Button(role: .destructive) {
                clearTemporaryFiles()
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("cache.clearTemporary".localized)
                }
            }
            
            Button(role: .destructive) {
                showingClearAllAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("cache.clearAll".localized)
                }
            }
        } header: {
            Text("cache.management.title".localized)
        } footer: {
            Text("cache.management.description".localized)
        }
    }
    
    // MARK: - Helpers
    
    private func updateLimitsFromCache() {
        memoryLimitMB = Double(cacheManager.getMemoryLimit()) / 1024.0 / 1024.0
        diskLimitMB = Double(cacheManager.getDiskLimit()) / 1024.0 / 1024.0
    }
    
    private func clearURLCache() {
        isClearing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            cacheManager.clearURLCache()
            // Очищаем также кеш изображений в памяти
            ImageCacheService.shared.clearMemoryCache()
            // Увеличиваем задержку для полной очистки и обновления размеров
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 секунды
            isClearing = false
            successMessage = "cache.clearURLSuccess".localized
            showSuccessMessage = true
            // Принудительно обновляем размеры
            cacheManager.updateCacheSizes()
        }
    }
    
    private func clearImageCache() {
        isClearing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            ImageCacheService.shared.clearAllCache()
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            isClearing = false
            successMessage = "cache.clearImageSuccess".localized
            showSuccessMessage = true
            cacheManager.updateCacheSizes()
        }
    }
    
    private func clearAvatarCache() {
        isClearing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            cacheManager.clearAvatarCache()
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
            isClearing = false
            successMessage = "cache.clearAvatarSuccess".localized
            showSuccessMessage = true
        }
    }
    
    private func clearTemporaryFiles() {
        isClearing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            await cacheManager.clearTemporaryFiles()
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
            isClearing = false
            successMessage = "cache.clearTemporarySuccess".localized
            showSuccessMessage = true
            cacheManager.updateCacheSizes()
        }
    }
    
    private func clearAllCaches() {
        isClearing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            cacheManager.clearAllCaches()
            // Очищаем также кеш изображений
            ImageCacheService.shared.clearAllCache()
            // Увеличиваем задержку для полной очистки всех кэшей
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 секунды
            isClearing = false
            successMessage = "cache.clearAllSuccess".localized
            showSuccessMessage = true
            // Принудительно обновляем размеры
            cacheManager.updateCacheSizes()
        }
    }
}

#Preview {
    CacheSettingsView()
}


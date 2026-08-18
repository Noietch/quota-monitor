import AppKit
import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: MonitorStore
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420, height: 590)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let snapshot = store.snapshot {
            HStack(spacing: 18) {
                AvailabilityRing(
                    available: snapshot.summary.usableNow,
                    total: snapshot.summary.supported
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(snapshot.group.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text("号池额度")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("共 \(snapshot.summary.accountsTotal)", systemImage: "person.2")
                        Label("支持 \(snapshot.summary.supported)", systemImage: "checkmark.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let recovery = QuotaDate.recoveryText(snapshot.summary.earliestRecovery) {
                        Label("最早恢复：\(recovery)", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
        } else {
            HStack(spacing: 14) {
                Image(systemName: "server.rack")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 4) {
                    Text("号池额度")
                        .font(.title3.weight(.semibold))
                    Text(store.hasToken ? "正在获取数据" : "需要完成设置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = store.snapshot {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedAccounts(snapshot.accounts)) { account in
                        AccountRow(account: account)
                        if account.id != sortedAccounts(snapshot.accounts).last?.id {
                            Divider().padding(.leading, 43)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        } else if store.isRefreshing {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("正在读取号池额度…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                Image(systemName: store.hasToken ? "wifi.exclamationmark" : "key")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(store.errorMessage ?? "暂无额度数据")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                if !store.hasToken {
                    Button("配置 API") { showingSettings = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let error = store.errorMessage, store.snapshot != nil {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                if let updated = store.lastUpdated {
                    Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("尚未更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("设置")

                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(store.isRefreshing ? .degrees(360) : .zero)
                        .animation(store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .help("立即刷新")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("退出")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func sortedAccounts(_ accounts: [QuotaAccount]) -> [QuotaAccount] {
        accounts.sorted {
            if $0.isUsable != $1.isUsable { return $0.isUsable && !$1.isUsable }
            if $0.supported != $1.supported { return $0.supported && !$1.supported }
            return $0.id < $1.id
        }
    }
}

struct AvailabilityRing: View {
    let available: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(available) / Double(total)
    }

    private var color: Color {
        if available == 0 { return .red }
        if progress < 0.35 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.17), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(available)")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("可用")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 78, height: 78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前可用 \(available)，共支持 \(total)")
    }
}

struct AccountRow: View {
    let account: QuotaAccount

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("账号 \(account.id)")
                        .font(.callout.weight(.medium))
                    Text(account.platform.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }

                if account.supported, let windows = account.windows, !windows.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(windows) { window in
                            QuotaBar(window: window)
                        }
                    }
                } else {
                    Text("暂不支持额度查询")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        if !account.supported { return .gray }
        return account.isUsable ? .green : .red
    }

    private var statusText: String {
        if !account.supported { return "不支持" }
        return account.isUsable ? "可用" : "已耗尽"
    }
}

struct QuotaBar: View {
    let window: QuotaWindow

    var body: some View {
        HStack(spacing: 8) {
            Text(window.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)

            ProgressView(value: window.displayPercent, total: 100)
                .progressViewStyle(.linear)
                .tint(barColor)
                .frame(height: 5)

            Text(percentText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)

            Text(resetText)
                .font(.caption2)
                .foregroundStyle(window.displayPercent >= 100 ? Color.orange : Color.secondary)
                .frame(width: 92, alignment: .trailing)
                .lineLimit(1)
        }
    }

    private var percentText: String {
        window.expired ? "0%" : "\(Int(window.displayPercent.rounded()))%"
    }

    private var resetText: String {
        if window.expired { return "已恢复" }
        return QuotaDate.recoveryText(window.resetAt) ?? "恢复时间未知"
    }

    private var barColor: Color {
        if window.displayPercent >= 95 { return .red }
        if window.displayPercent >= 75 { return .orange }
        return .green
    }
}

struct SettingsView: View {
    @ObservedObject var store: MonitorStore
    @Environment(\.dismiss) private var dismiss

    @State private var endpoint: String
    @State private var token: String
    @State private var interval: Int
    @State private var errorMessage: String?

    init(store: MonitorStore) {
        self.store = store
        _endpoint = State(initialValue: store.endpoint)
        _token = State(initialValue: store.token)
        _interval = State(initialValue: store.refreshIntervalMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("额度监控设置")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("接口地址")
                    .font(.caption.weight(.medium))
                TextField("https://example.com/quota", text: $endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("API Token")
                    .font(.caption.weight(.medium))
                SecureField("sk-…", text: $token)
                    .textFieldStyle(.roundedBorder)
                Label("Token 仅保存在 macOS Keychain", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("自动刷新")
                    .font(.callout)
                Spacer()
                Picker("自动刷新", selection: $interval) {
                    Text("1 分钟").tag(1)
                    Text("5 分钟").tag(5)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                }
                .labelsHidden()
                .frame(width: 100)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if store.hasToken {
                    Button("移除 Token", role: .destructive) {
                        removeToken()
                    }
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存并刷新") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 430)
    }

    private func save() {
        do {
            try store.updateSettings(endpoint: endpoint, token: token, refreshIntervalMinutes: interval)
            dismiss()
            Task { await store.refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeToken() {
        do {
            try store.removeToken()
            token = ""
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

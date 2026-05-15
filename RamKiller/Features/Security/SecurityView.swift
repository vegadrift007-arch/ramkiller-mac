// RamKiller/Features/Security/SecurityView.swift
import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var coordinator: SecurityScanCoordinator
    @State private var confirmRemove: SecurityFinding?

    private var hasScanned: Bool {
        if case .idle = coordinator.scanState { return false }
        if case .scanning = coordinator.scanState { return false }
        return true
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                statusBanner
                ForEach(SecurityCheckType.allCases, id: \.self) { sectionGroup(for: $0) }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle(String(localized: "Security"))
        .toolbar {
            ToolbarItem {
                if let date = coordinator.lastScanDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(Theme.caption).foregroundStyle(Theme.mute)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await coordinator.scan() } } label: {
                    Label(String(localized: "Scan Now"), systemImage: "shield.checkerboard")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(coordinator.scanState != .idle)
            }
        }
        .confirmationDialog(
            String(localized: "Remove this item?"),
            isPresented: .init(
                get: { confirmRemove != nil },
                set: { if !$0 { confirmRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Move to Trash"), role: .destructive) {
                if let f = confirmRemove { Task { await coordinator.remove(f) } }
                confirmRemove = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { confirmRemove = nil }
        } message: {
            Text(confirmRemove?.detail ?? "")
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        switch coordinator.scanState {
        case .idle:
            HStack(spacing: 10) {
                Image(systemName: "shield").foregroundStyle(Theme.mute)
                Text(String(localized: "Run a scan to check your Mac for threats"))
                    .font(Theme.bodyText).foregroundStyle(Theme.mute)
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBg))

        case .scanning(let p):
            HStack(spacing: 12) {
                ProgressView(value: p).frame(width: 100)
                Text(String(localized: "Scanning...")).font(Theme.caption).foregroundStyle(Theme.mute)
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBg))

        case .done:
            let serious = coordinator.findings.filter { $0.severity >= .warning }
            if serious.isEmpty {
                bannerRow(icon: "checkmark.shield.fill", color: Theme.accent,
                          title: String(localized: "All clear"),
                          subtitle: String(localized: "No threats detected"))
            } else {
                bannerRow(icon: "exclamationmark.triangle.fill", color: Theme.warn,
                          title: String(format: String(localized: "%d issue(s) found"), serious.count),
                          subtitle: String(localized: "Review the findings below and take action"))
            }
        }
    }

    private func bannerRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.headline(14)).foregroundStyle(color)
                Text(subtitle).font(Theme.caption).foregroundStyle(Theme.mute)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Section groups

    @ViewBuilder
    private func sectionGroup(for type: SecurityCheckType) -> some View {
        let typeFindings = coordinator.findings.filter { $0.checkType == type }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(type.sectionTitle).vqEyebrow()
                if !typeFindings.isEmpty {
                    let color = typeFindings.contains { $0.severity == .critical } ? Theme.danger : Theme.warn
                    Text("· \(typeFindings.count)").vqEyebrow(color: color)
                }
            }
            if hasScanned {
                if typeFindings.isEmpty {
                    cleanRow(for: type)
                } else {
                    ForEach(typeFindings) { findingRow($0) }
                }
            } else {
                placeholderRow
            }
        }
    }

    private var placeholderRow: some View {
        HStack {
            Text("—").font(Theme.caption).foregroundStyle(Theme.mute)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cardBg))
    }

    private func cleanRow(for type: SecurityCheckType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            Text(type.cleanMessage).font(Theme.bodyText).foregroundStyle(Theme.accent)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent.opacity(0.15), lineWidth: 1))
    }

    private func findingRow(_ finding: SecurityFinding) -> some View {
        let color = finding.severity == .critical ? Theme.danger : Theme.warn
        return HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 7, height: 7).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(Theme.bodyText).fontWeight(.semibold).foregroundStyle(color)
                Text(finding.detail)
                    .font(Theme.caption).foregroundStyle(Theme.mute).lineLimit(2)
            }
            Spacer()
            HStack(spacing: 6) {
                Button(String(localized: "Ignore")) { coordinator.ignore(finding) }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.mute)
                if finding.path != nil {
                    Button(String(localized: "Remove")) { confirmRemove = finding }
                        .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.danger)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}
